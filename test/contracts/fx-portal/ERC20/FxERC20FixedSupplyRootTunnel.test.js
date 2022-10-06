const {ethers} = require('hardhat');
const {expect} = require('chai');
const {EmptyByte, ZeroAddress} = require('@animoca/ethereum-contracts/src/constants');
const {getForwarderRegistryAddress} = require('@animoca/ethereum-contracts/test/helpers/run');
const {loadFixture} = require('@animoca/ethereum-contracts/test/helpers/fixtures');
const {deployContract} = require('@animoca/ethereum-contracts/test/helpers/contract');

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
    this.fxRoot = await deployContract('FxRootMock', this.stateSender.address);
    this.contract = await deployContract(
      'FxERC20FixedSupplyRootTunnelMock',
      ZeroAddress,
      this.fxRoot.address,
      this.fxERC20Logic.address,
      forwarderRegistryAddress
    );

    this.rootToken = await deployContract('ERC20Mock', tokenName, tokenSymbol, decimals, forwarderRegistryAddress);
    await this.rootToken.grantRole(await this.rootToken.MINTER_ROLE(), deployer.address);
    await this.rootToken.mint(this.contract.address, initialSupply);
    await this.rootToken.setTokenURI(tokenURI);
  };

  beforeEach(async function () {
    await loadFixture(fixture, this);
  });

  describe('mapToken(address)', function () {
    beforeEach(async function () {
      this.receipt = await this.contract.mapToken(this.rootToken.address);
    });

    context('initial mapping request', function () {
      it('emits a TokenMappedERC20 event', async function () {
        const childToken = await this.contract.childToken(this.rootToken.address);
        await expect(this.receipt).to.emit(this.contract, 'TokenMappedERC20').withArgs(this.rootToken.address, childToken);
      });

      it('emits a StateSynced event', async function () {
        await expect(this.receipt)
          .to.emit(this.stateSender, 'StateSynced')
          .withArgs(
            0,
            await this.contract.fxChildTunnel(),
            ethers.utils.defaultAbiCoder.encode(
              ['address', 'address', 'bytes'],
              [
                this.contract.address,
                ZeroAddress,
                ethers.utils.defaultAbiCoder.encode(
                  ['bytes32', 'bytes'],
                  [
                    ethers.utils.id('MAP_TOKEN'),
                    ethers.utils.defaultAbiCoder.encode(
                      ['address', 'bytes'],
                      [
                        this.rootToken.address,
                        ethers.utils.defaultAbiCoder.encode(
                          ['uint256', 'string', 'string', 'uint8', 'string', 'address'],
                          [initialSupply, tokenName, tokenSymbol, decimals, tokenURI, deployer.address]
                        ),
                      ]
                    ),
                  ]
                ),
              ]
            )
          );
      });

      it('sets up the mapping', async function () {
        const childToken = await this.contract.childToken(this.rootToken.address);
        expect(await this.contract.rootToChildToken(this.rootToken.address)).to.equal(childToken);
      });
    });

    context('subsequent mapping request', function () {
      beforeEach(async function () {
        this.receipt = await this.contract.mapToken(this.rootToken.address);
      });
      it('does not emit a TokenMappedERC20 event', async function () {
        await expect(this.receipt).to.not.emit(this.contract, 'TokenMappedERC20');
      });

      it('does not emit a StateSynced event', async function () {
        await expect(this.receipt).to.not.emit(this.stateSender, 'StateSynced');
      });
    });
  });

  describe('__processMessageFromChild(bytes) withdrawal', function () {
    it('reverts if the mapping is incorrect', async function () {
      const message = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address', 'uint256'],
        [ZeroAddress, deployer.address, deployer.address, withdrawalAmount]
      );
      await expect(this.contract.__processMessageFromChild(message))
        .to.be.revertedWithCustomError(this.contract, 'FxERC20InvalidMappingOnExit')
        .withArgs(ZeroAddress, deployer.address, ZeroAddress);
    });

    context('when successful', function () {
      beforeEach(async function () {
        const message = ethers.utils.defaultAbiCoder.encode(
          ['address', 'address', 'address', 'uint256'],
          [this.rootToken.address, await this.contract.rootToChildToken(this.rootToken.address), deployer.address, withdrawalAmount]
        );
        this.receipt = await this.contract.__processMessageFromChild(message);
      });

      it('unescrows the withdrawal amount', async function () {
        await expect(this.receipt).to.emit(this.rootToken, 'Transfer').withArgs(this.contract.address, deployer.address, withdrawalAmount);
      });

      it('emits a FxWithdrawERC20 event', async function () {
        await expect(this.receipt)
          .to.emit(this.contract, 'FxWithdrawERC20')
          .withArgs(this.rootToken.address, await this.contract.rootToChildToken(this.rootToken.address), deployer.address, withdrawalAmount);
      });
    });
  });

  describe('deposit', function () {
    beforeEach(async function () {
      this.receipt = await this.contract.mapToken(this.rootToken.address);
      const message = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address', 'uint256'],
        [this.rootToken.address, await this.contract.rootToChildToken(this.rootToken.address), deployer.address, withdrawalAmount]
      );
      await this.contract.__processMessageFromChild(message);
    });

    function deposits() {
      it('escrows the deposit amount', async function () {
        await expect(this.receipt).to.emit(this.rootToken, 'Transfer').withArgs(deployer.address, this.contract.address, depositAmount);
      });

      it('emits a FxDepositERC20 event', async function () {
        await expect(this.receipt)
          .to.emit(this.contract, 'FxDepositERC20')
          .withArgs(this.rootToken.address, deployer.address, deployer.address, depositAmount);
      });

      it('emits a StateSynced event', async function () {
        await expect(this.receipt)
          .to.emit(this.stateSender, 'StateSynced')
          .withArgs(
            0,
            await this.contract.fxChildTunnel(),
            ethers.utils.defaultAbiCoder.encode(
              ['address', 'address', 'bytes'],
              [
                this.contract.address,
                ZeroAddress,
                ethers.utils.defaultAbiCoder.encode(
                  ['bytes32', 'bytes'],
                  [
                    ethers.utils.id('DEPOSIT'),
                    ethers.utils.defaultAbiCoder.encode(
                      ['address', 'address', 'address', 'uint256'],
                      [this.rootToken.address, deployer.address, deployer.address, depositAmount]
                    ),
                  ]
                ),
              ]
            )
          );
      });
    }

    context('deposit(address,uint256)', function () {
      context('when successful', function () {
        beforeEach(async function () {
          await this.rootToken.approve(this.contract.address, depositAmount);
          this.receipt = await this.contract.deposit(this.rootToken.address, depositAmount);
        });

        deposits();
      });
    });

    context('depositTo(address,address,uint256)', function () {
      context('when successful', function () {
        beforeEach(async function () {
          await this.rootToken.approve(this.contract.address, depositAmount);
          this.receipt = await this.contract.depositTo(this.rootToken.address, deployer.address, depositAmount);
        });

        deposits();
      });
    });

    context('onERC20Received(address,address,uint256,bytes) receiver is from', function () {
      context('when successful', function () {
        beforeEach(async function () {
          this.receipt = await this.rootToken.safeTransfer(this.contract.address, depositAmount, EmptyByte);
        });

        deposits();
      });
    });

    context('onERC20Received(address,address,uint256,bytes) encoded receiver', function () {
      context('when successful', function () {
        beforeEach(async function () {
          this.receipt = await this.rootToken.safeTransfer(
            this.contract.address,
            depositAmount,
            ethers.utils.defaultAbiCoder.encode(['address'], [deployer.address])
          );
        });

        deposits();
      });
    });
  });
});
