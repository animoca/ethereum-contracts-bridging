const {ethers} = require('hardhat');
const {expect} = require('chai');
const {loadFixture} = require('@animoca/ethereum-contract-helpers/src/test/fixtures');
const {deployContract} = require('@animoca/ethereum-contract-helpers/src/test/deploy');
const {getForwarderRegistryAddress} = require('@animoca/ethereum-contracts/test/helpers/registries');

const initialSupply = 1234;
const tokenName = 'name';
const tokenSymbol = 'symbol';
const decimals = 18;
const tokenURI = 'test';

const depositAmount = '12';
const withdrawalAmount = '123';

describe('FxERC20FixedSupplyRootTunnel', function () {
  let deployer, other;

  before(async function () {
    [deployer, other] = await ethers.getSigners();
  });

  const fixture = async function () {
    const forwarderRegistryAddress = await getForwarderRegistryAddress();

    this.fxERC20Logic = await deployContract('FxERC20FixedSupply', forwarderRegistryAddress);
    this.stateSender = await deployContract('StateSenderMock');
    this.fxRoot = await deployContract('FxRootMock', await this.stateSender.getAddress());
    this.contract = await deployContract(
      'FxERC20FixedSupplyRootTunnelMock',
      ethers.ZeroAddress,
      await this.fxRoot.getAddress(),
      await this.fxERC20Logic.getAddress(),
      forwarderRegistryAddress,
    );

    this.rootToken = await deployContract(
      'ERC20FixedSupply',
      tokenName,
      tokenSymbol,
      decimals,
      [await this.contract.getAddress()],
      [initialSupply],
      forwarderRegistryAddress,
    );
    await this.rootToken.setTokenURI(tokenURI);
  };

  beforeEach(async function () {
    await loadFixture(fixture, this);
  });

  describe('mapToken(address)', function () {
    beforeEach(async function () {
      this.receipt = await this.contract.mapToken(await this.rootToken.getAddress());
    });

    context('initial mapping request', function () {
      it('emits a FxERC20TokenMapping event', async function () {
        const childToken = await this.contract.childToken(await this.rootToken.getAddress());
        await expect(this.receipt)
          .to.emit(this.contract, 'FxERC20TokenMapping')
          .withArgs(await this.rootToken.getAddress(), childToken);
      });

      it('emits a StateSynced event', async function () {
        await expect(this.receipt)
          .to.emit(this.stateSender, 'StateSynced')
          .withArgs(
            0,
            await this.contract.fxChildTunnel(),
            ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'address', 'bytes'],
              [
                await this.contract.getAddress(),
                ethers.ZeroAddress,
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ['bytes32', 'bytes'],
                  [
                    ethers.id('MAP_TOKEN'),
                    ethers.AbiCoder.defaultAbiCoder().encode(
                      ['address', 'bytes'],
                      [
                        await this.rootToken.getAddress(),
                        ethers.AbiCoder.defaultAbiCoder().encode(
                          ['uint256', 'string', 'string', 'uint8', 'string', 'address'],
                          [initialSupply, tokenName, tokenSymbol, decimals, tokenURI, deployer.address],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
      });

      it('sets up the mapping', async function () {
        const childToken = await this.contract.childToken(await this.rootToken.getAddress());
        expect(await this.contract.rootToChildToken(await this.rootToken.getAddress())).to.equal(childToken);
      });
    });

    context('subsequent mapping request', function () {
      beforeEach(async function () {
        this.receipt = await this.contract.mapToken(await this.rootToken.getAddress());
      });
      it('does not emit a FxERC20TokenMapping event', async function () {
        await expect(this.receipt).to.not.emit(this.contract, 'FxERC20TokenMapping');
      });

      it('does not emit a StateSynced event', async function () {
        await expect(this.receipt).to.not.emit(this.stateSender, 'StateSynced');
      });
    });
  });

  describe('__processMessageFromChild(bytes) withdrawal', function () {
    it('reverts if the mapping is incorrect', async function () {
      const message = ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'address', 'address', 'address', 'uint256'],
        [ethers.ZeroAddress, deployer.address, deployer.address, deployer.address, withdrawalAmount],
      );
      await expect(this.contract.__processMessageFromChild(message))
        .to.be.revertedWithCustomError(this.contract, 'FxERC20InvalidMappingOnExit')
        .withArgs(ethers.ZeroAddress, deployer.address, ethers.ZeroAddress);
    });

    context('when successful', function () {
      beforeEach(async function () {
        const message = ethers.AbiCoder.defaultAbiCoder().encode(
          ['address', 'address', 'address', 'address', 'uint256'],
          [
            await this.rootToken.getAddress(),
            await this.contract.rootToChildToken(await this.rootToken.getAddress()),
            other.address,
            deployer.address,
            withdrawalAmount,
          ],
        );
        this.receipt = await this.contract.__processMessageFromChild(message);
      });

      it('unescrows the withdrawal amount', async function () {
        await expect(this.receipt)
          .to.emit(this.rootToken, 'Transfer')
          .withArgs(await this.contract.getAddress(), deployer.address, withdrawalAmount);
      });

      it('emits a FxERC20Withdrawal event', async function () {
        await expect(this.receipt)
          .to.emit(this.contract, 'FxERC20Withdrawal')
          .withArgs(
            await this.rootToken.getAddress(),
            await this.contract.rootToChildToken(await this.rootToken.getAddress()),
            other.address,
            deployer.address,
            withdrawalAmount,
          );
      });
    });
  });

  describe('deposit', function () {
    beforeEach(async function () {
      await this.contract.mapToken(await this.rootToken.getAddress());
      const message = ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'address', 'address', 'address', 'uint256'],
        [
          await this.rootToken.getAddress(),
          await this.contract.rootToChildToken(await this.rootToken.getAddress()),
          other.address,
          deployer.address,
          withdrawalAmount,
        ],
      );
      await this.contract.__processMessageFromChild(message);
    });

    function deposits() {
      it('escrows the deposit amount', async function () {
        await expect(this.receipt)
          .to.emit(this.rootToken, 'Transfer')
          .withArgs(deployer.address, await this.contract.getAddress(), depositAmount);
      });

      it('emits a FxERC20Deposit event', async function () {
        await expect(this.receipt)
          .to.emit(this.contract, 'FxERC20Deposit')
          .withArgs(
            await this.rootToken.getAddress(),
            await this.contract.rootToChildToken(await this.rootToken.getAddress()),
            deployer.address,
            this.recipient.address,
            depositAmount,
          );
      });

      it('emits a StateSynced event', async function () {
        await expect(this.receipt)
          .to.emit(this.stateSender, 'StateSynced')
          .withArgs(
            0,
            await this.contract.fxChildTunnel(),
            ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'address', 'bytes'],
              [
                await this.contract.getAddress(),
                ethers.ZeroAddress,
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ['bytes32', 'bytes'],
                  [
                    ethers.id('DEPOSIT'),
                    ethers.AbiCoder.defaultAbiCoder().encode(
                      ['address', 'address', 'address', 'uint256'],
                      [await this.rootToken.getAddress(), deployer.address, this.recipient.address, depositAmount],
                    ),
                  ],
                ),
              ],
            ),
          );
      });
    }

    context('deposit(address,uint256)', function () {
      context('when successful', function () {
        beforeEach(async function () {
          await this.rootToken.approve(await this.contract.getAddress(), depositAmount);
          this.recipient = deployer;
          this.receipt = await this.contract.deposit(await this.rootToken.getAddress(), depositAmount);
        });

        deposits();
      });
    });

    context('depositTo(address,address,uint256)', function () {
      it('reverts if the deposit recipient is the zero address', async function () {
        await expect(this.contract.depositTo(await this.rootToken.getAddress(), ethers.ZeroAddress, depositAmount)).to.be.revertedWithCustomError(
          this.contract,
          'FxERC20InvalidDepositAddress',
        );
      });

      context('when successful', function () {
        beforeEach(async function () {
          await this.rootToken.approve(await this.contract.getAddress(), depositAmount);
          this.recipient = other;
          this.receipt = await this.contract.depositTo(await this.rootToken.getAddress(), this.recipient.address, depositAmount);
        });

        deposits();
      });
    });

    context('onERC20Received(address,address,uint256,bytes) receiver is from', function () {
      context('when successful', function () {
        beforeEach(async function () {
          this.recipient = deployer;
          this.receipt = await this.rootToken.safeTransfer(await this.contract.getAddress(), depositAmount, '0x');
        });

        deposits();
      });
    });

    context('onERC20Received(address,address,uint256,bytes) encoded receiver', function () {
      it('reverts if the deposit recipient is the zero address', async function () {
        await expect(
          this.rootToken.safeTransfer(
            await this.contract.getAddress(),
            depositAmount,
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [ethers.ZeroAddress]),
          ),
        ).to.be.revertedWithCustomError(this.contract, 'FxERC20InvalidDepositAddress');
      });

      context('when successful', function () {
        beforeEach(async function () {
          this.recipient = other;
          this.receipt = await this.rootToken.safeTransfer(
            await this.contract.getAddress(),
            depositAmount,
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [this.recipient.address]),
          );
        });

        deposits();
      });
    });
  });
});
