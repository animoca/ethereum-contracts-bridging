const {ethers} = require('hardhat');
const {expect} = require('chai');
const {constants} = ethers;
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

describe('FxERC20MintBurnRootTunnel', function () {
  let deployer, other;

  before(async function () {
    [deployer, other] = await ethers.getSigners();
  });

  const fixture = async function () {
    const forwarderRegistryAddress = await getForwarderRegistryAddress();

    this.fxERC20Logic = await deployContract('FxERC20MintBurn', forwarderRegistryAddress);
    this.stateSender = await deployContract('StateSenderMock');
    this.fxRoot = await deployContract('FxRootMock', this.stateSender.address);
    this.contract = await deployContract(
      'FxERC20MintBurnRootTunnelMock',
      constants.AddressZero,
      this.fxRoot.address,
      this.fxERC20Logic.address,
      forwarderRegistryAddress
    );

    this.rootToken = await deployContract('ERC20MintBurn', tokenName, tokenSymbol, decimals, forwarderRegistryAddress);
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
      it('emits a FxERC20TokenMapping event', async function () {
        const childToken = await this.contract.childToken(this.rootToken.address);
        await expect(this.receipt).to.emit(this.contract, 'FxERC20TokenMapping').withArgs(this.rootToken.address, childToken);
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
                constants.AddressZero,
                ethers.utils.defaultAbiCoder.encode(
                  ['bytes32', 'bytes'],
                  [
                    ethers.utils.id('MAP_TOKEN'),
                    ethers.utils.defaultAbiCoder.encode(
                      ['address', 'bytes'],
                      [
                        this.rootToken.address,
                        ethers.utils.defaultAbiCoder.encode(
                          ['string', 'string', 'uint8', 'string', 'address'],
                          [tokenName, tokenSymbol, decimals, tokenURI, deployer.address]
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
      const message = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address', 'address', 'uint256'],
        [constants.AddressZero, deployer.address, deployer.address, deployer.address, withdrawalAmount]
      );
      await expect(this.contract.__processMessageFromChild(message))
        .to.be.revertedWithCustomError(this.contract, 'FxERC20InvalidMappingOnExit')
        .withArgs(constants.AddressZero, deployer.address, constants.AddressZero);
    });

    context('when successful', function () {
      beforeEach(async function () {
        const message = ethers.utils.defaultAbiCoder.encode(
          ['address', 'address', 'address', 'address', 'uint256'],
          [this.rootToken.address, await this.contract.rootToChildToken(this.rootToken.address), other.address, deployer.address, withdrawalAmount]
        );
        await this.rootToken.grantRole(await this.rootToken.MINTER_ROLE(), this.contract.address);
        this.receipt = await this.contract.__processMessageFromChild(message);
      });

      it('mints the withdrawal amount', async function () {
        await expect(this.receipt).to.emit(this.rootToken, 'Transfer').withArgs(constants.AddressZero, deployer.address, withdrawalAmount);
      });

      it('emits a FxERC20Withdrawal event', async function () {
        await expect(this.receipt)
          .to.emit(this.contract, 'FxERC20Withdrawal')
          .withArgs(
            this.rootToken.address,
            await this.contract.rootToChildToken(this.rootToken.address),
            other.address,
            deployer.address,
            withdrawalAmount
          );
      });
    });
  });

  describe('deposit', function () {
    beforeEach(async function () {
      await this.contract.mapToken(this.rootToken.address);
      await this.rootToken.grantRole(await this.rootToken.MINTER_ROLE(), this.contract.address);
      const message = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address', 'address', 'uint256'],
        [this.rootToken.address, await this.contract.rootToChildToken(this.rootToken.address), other.address, deployer.address, withdrawalAmount]
      );
      await this.contract.__processMessageFromChild(message);
    });

    function deposits(fromReceiverInterface) {
      if (fromReceiverInterface) {
        it('transfers the deposit amount to the tunnel', async function () {
          await expect(this.receipt).to.emit(this.rootToken, 'Transfer').withArgs(deployer.address, this.contract.address, depositAmount);
        });

        it('burns the deposit amount', async function () {
          await expect(this.receipt).to.emit(this.rootToken, 'Transfer').withArgs(this.contract.address, constants.AddressZero, depositAmount);
        });
      } else {
        it('directly burns the deposit amount', async function () {
          await expect(this.receipt).to.emit(this.rootToken, 'Transfer').withArgs(deployer.address, constants.AddressZero, depositAmount);
        });
      }

      it('emits a FxERC20Deposit event', async function () {
        await expect(this.receipt)
          .to.emit(this.contract, 'FxERC20Deposit')
          .withArgs(
            this.rootToken.address,
            await this.contract.rootToChildToken(this.rootToken.address),
            deployer.address,
            this.recipient.address,
            depositAmount
          );
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
                constants.AddressZero,
                ethers.utils.defaultAbiCoder.encode(
                  ['bytes32', 'bytes'],
                  [
                    ethers.utils.id('DEPOSIT'),
                    ethers.utils.defaultAbiCoder.encode(
                      ['address', 'address', 'address', 'uint256'],
                      [this.rootToken.address, deployer.address, this.recipient.address, depositAmount]
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
          this.recipient = deployer;
          this.receipt = await this.contract.deposit(this.rootToken.address, depositAmount);
        });

        deposits(false);
      });
    });

    context('depositTo(address,address,uint256)', function () {
      it('reverts if the deposit recipient is the zero address', async function () {
        await expect(this.contract.depositTo(this.rootToken.address, constants.AddressZero, depositAmount)).to.be.revertedWithCustomError(
          this.contract,
          'FxERC20InvalidDepositAddress'
        );
      });

      context('when successful', function () {
        beforeEach(async function () {
          await this.rootToken.approve(this.contract.address, depositAmount);
          this.recipient = other;
          this.receipt = await this.contract.depositTo(this.rootToken.address, this.recipient.address, depositAmount);
        });

        deposits(false);
      });
    });

    context('onERC20Received(address,address,uint256,bytes) receiver is from', function () {
      context('when successful', function () {
        beforeEach(async function () {
          this.recipient = deployer;
          this.receipt = await this.rootToken.safeTransfer(this.contract.address, depositAmount, '0x');
        });

        deposits(true);
      });
    });

    context('onERC20Received(address,address,uint256,bytes) encoded receiver', function () {
      it('reverts if the deposit recipient is the zero address', async function () {
        await expect(
          this.rootToken.safeTransfer(this.contract.address, depositAmount, ethers.utils.defaultAbiCoder.encode(['address'], [constants.AddressZero]))
        ).to.be.revertedWithCustomError(this.contract, 'FxERC20InvalidDepositAddress');
      });

      context('when successful', function () {
        beforeEach(async function () {
          this.recipient = other;
          this.receipt = await this.rootToken.safeTransfer(
            this.contract.address,
            depositAmount,
            ethers.utils.defaultAbiCoder.encode(['address'], [this.recipient.address])
          );
        });

        deposits(true);
      });
    });
  });
});
