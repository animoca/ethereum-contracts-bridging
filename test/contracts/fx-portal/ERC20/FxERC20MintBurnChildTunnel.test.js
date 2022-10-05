const {ethers} = require('hardhat');
const {expect} = require('chai');
const {EmptyByte, ZeroAddress} = require('@animoca/ethereum-contracts/src/constants');
const {getForwarderRegistryAddress} = require('@animoca/ethereum-contracts/test/helpers/run');
const {loadFixture} = require('@animoca/ethereum-contracts/test/helpers/fixtures');
const {deployContract} = require('@animoca/ethereum-contracts/test/helpers/contract');

const rootToken = '0x0000000000000000000000000000000000000001';
const rootTokenWrongMapping = '0x0000000000000000000000000000000000000002';

const tokenName = '';
const tokenSymbol = '';
const decimals = 18;
const tokenURI = 'test';

const depositAmount = '123';
const withdrawalAmount = '12';

describe('FxERC20MintBurnChildTunnel', function () {
  let deployer, other;

  let mappingMessage, depositMessage;

  before(async function () {
    [deployer, other] = await ethers.getSigners();

    mappingMessage = ethers.utils.defaultAbiCoder.encode(
      ['bytes32', 'bytes'],
      [
        ethers.utils.id('MAP_TOKEN'),
        ethers.utils.defaultAbiCoder.encode(
          ['address', 'bytes'],
          [
            rootToken,
            ethers.utils.defaultAbiCoder.encode(
              ['string', 'string', 'uint8', 'string', 'address'],
              [tokenName, tokenSymbol, 18, tokenURI, deployer.address]
            ),
          ]
        ),
      ]
    );

    depositMessage = ethers.utils.defaultAbiCoder.encode(
      ['bytes32', 'bytes'],
      [
        ethers.utils.id('DEPOSIT'),
        ethers.utils.defaultAbiCoder.encode(['address', 'address', 'uint256'], [rootToken, deployer.address, depositAmount]),
      ]
    );
  });

  const fixture = async function () {
    const forwarderRegistryAddress = await getForwarderRegistryAddress();

    this.fxERC20Logic = await deployContract('FxERC20MintBurn', forwarderRegistryAddress);
    this.contract = await deployContract('FxERC20MintBurnChildTunnel', deployer.address, this.fxERC20Logic.address, forwarderRegistryAddress);
    this.unmappedTokenToZeroAddress = await deployContract('FxERC20MintBurnMock', [deployer.address], [withdrawalAmount], forwarderRegistryAddress);
    await this.unmappedTokenToZeroAddress.initialize(this.contract.address, ZeroAddress, '', '', 18, '', deployer.address);
    this.unmappedTokenToWrongAddress = await deployContract('FxERC20MintBurnMock', [deployer.address], [withdrawalAmount], forwarderRegistryAddress);
    await this.unmappedTokenToWrongAddress.initialize(this.contract.address, rootTokenWrongMapping, '', '', 18, '', deployer.address);
    await this.contract.setFxRootTunnel(deployer.address);
  };

  beforeEach(async function () {
    await loadFixture(fixture, this);
  });

  describe('constructor', function () {
    it('reverts if the ERC20 logic address is not a contract', async function () {
      await expect(
        deployContract('FxERC20MintBurnChildTunnel', deployer.address, deployer.address, await getForwarderRegistryAddress())
      ).to.be.revertedWithCustomError(this.contract, 'FxERC20ChildTokenLogicNotContract');
    });
  });

  describe('processMessageFromRoot(uint256,address,bytes)', function () {
    it('reverts if not sent by the fxChild', async function () {
      await expect(this.contract.connect(other).processMessageFromRoot(0, deployer.address, mappingMessage)).to.be.revertedWith(
        'FxBaseChildTunnel: INVALID_SENDER'
      );
    });

    it('reverts if the sender argument is not the FxRootTunnel', async function () {
      await expect(this.contract.processMessageFromRoot(0, ZeroAddress, mappingMessage)).to.be.revertedWith(
        'FxBaseChildTunnel: INVALID_SENDER_FROM_ROOT'
      );
    });

    it('reverts with an invalid sync type', async function () {
      const invalidSyncType = ethers.utils.id('WRONG');
      const message = ethers.utils.defaultAbiCoder.encode(['bytes32', 'bytes'], [invalidSyncType, ethers.utils.toUtf8Bytes('')]);
      await expect(this.contract.processMessageFromRoot(0, deployer.address, message))
        .to.be.revertedWithCustomError(this.contract, 'FxERC20InvalidSyncType')
        .withArgs(invalidSyncType);
    });

    context('token mapping', function () {
      it('reverts if the root token is already mapped', async function () {
        await this.contract.processMessageFromRoot(0, deployer.address, mappingMessage);
        const childToken = await this.contract.rootToChildToken(rootToken);
        await expect(this.contract.processMessageFromRoot(0, deployer.address, mappingMessage))
          .to.be.revertedWithCustomError(this.contract, 'FxERC20TokenAlreadyMapped')
          .withArgs(rootToken, childToken);
      });

      context('when successful', function () {
        beforeEach(async function () {
          this.receipt = await this.contract.processMessageFromRoot(0, deployer.address, mappingMessage);
        });

        it('deploys a new FxERC20 token', async function () {
          const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
          expect(await childToken.totalSupply()).to.equal(0);
          expect(await childToken.name()).to.equal(tokenName + ' (Polygon)');
          expect(await childToken.symbol()).to.equal(tokenSymbol + 'p');
          expect(await childToken.decimals()).to.equal(decimals);
          expect(await childToken.tokenURI()).to.equal(tokenURI);
          expect(await childToken.owner()).to.equal(deployer.address);
        });

        it('emits a TokenMapped event', async function () {
          const childToken = await this.contract.rootToChildToken(rootToken);
          await expect(this.receipt).to.emit(this.contract, 'TokenMapped').withArgs(rootToken, childToken);
        });
      });
    });

    context('deposit', function () {
      beforeEach(async function () {
        await this.contract.processMessageFromRoot(0, deployer.address, mappingMessage);
        const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
        await childToken.grantRole(await childToken.MINTER_ROLE(), this.contract.address);
        this.receipt = await this.contract.processMessageFromRoot(0, deployer.address, depositMessage);
      });

      it('mints the deposit amount to the recipient', async function () {
        const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
        await expect(this.receipt).to.emit(childToken, 'Transfer').withArgs(ZeroAddress, deployer.address, depositAmount);
      });
    });
  });

  describe('withdrawal', function () {
    beforeEach(async function () {
      await this.contract.processMessageFromRoot(0, deployer.address, mappingMessage);
      const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
      await childToken.grantRole(await childToken.MINTER_ROLE(), this.contract.address);
      await this.contract.processMessageFromRoot(0, deployer.address, depositMessage);
    });

    function withdraws(fromReceiverInterface) {
      if (fromReceiverInterface) {
        it('transfers the withdrawal amount to the tunnel', async function () {
          const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
          await expect(this.receipt).to.emit(childToken, 'Transfer').withArgs(deployer.address, this.contract.address, withdrawalAmount);
        });
        it('burns the withdrawal amount', async function () {
          const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
          await expect(this.receipt).to.emit(childToken, 'Transfer').withArgs(this.contract.address, ZeroAddress, withdrawalAmount);
        });
      } else {
        it('directly burns the withdrawal amount', async function () {
          const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
          await expect(this.receipt).to.emit(childToken, 'Transfer').withArgs(deployer.address, ZeroAddress, withdrawalAmount);
        });
      }

      it('emits a MessageSent event', async function () {
        const childToken = await this.contract.rootToChildToken(rootToken);
        await expect(this.receipt)
          .emit(this.contract, 'MessageSent')
          .withArgs(
            ethers.utils.defaultAbiCoder.encode(
              ['address', 'address', 'address', 'uint256'],
              [rootToken, childToken, deployer.address, withdrawalAmount]
            )
          );
      });
    }

    context('withdraw(address,uint256)', function () {
      it('reverts if the token is not mapped (zero address)', async function () {
        await expect(this.contract.withdraw(this.unmappedTokenToZeroAddress.address, withdrawalAmount))
          .to.be.revertedWithCustomError(this.contract, 'FxERC20TokenNotMapped')
          .withArgs(ZeroAddress);
      });

      it('reverts if the token is not mapped (wrong mapping)', async function () {
        await expect(this.contract.withdraw(this.unmappedTokenToWrongAddress.address, withdrawalAmount))
          .to.be.revertedWithCustomError(this.contract, 'FxERC20TokenNotMapped')
          .withArgs(rootTokenWrongMapping);
      });

      context('when successful', function () {
        beforeEach(async function () {
          const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
          await childToken.approve(this.contract.address, withdrawalAmount);
          this.receipt = await this.contract.withdraw(childToken.address, withdrawalAmount);
        });

        withdraws(false);
      });
    });

    context('withdrawTo(address,uint256)', function () {
      it('reverts if the token is not mapped (zero address)', async function () {
        await expect(this.contract.withdrawTo(this.unmappedTokenToZeroAddress.address, deployer.address, withdrawalAmount))
          .to.be.revertedWithCustomError(this.contract, 'FxERC20TokenNotMapped')
          .withArgs(ZeroAddress);
      });

      it('reverts if the token is not mapped (wrong mapping)', async function () {
        await expect(this.contract.withdrawTo(this.unmappedTokenToWrongAddress.address, deployer.address, withdrawalAmount))
          .to.be.revertedWithCustomError(this.contract, 'FxERC20TokenNotMapped')
          .withArgs(rootTokenWrongMapping);
      });

      context('when successful', function () {
        beforeEach(async function () {
          const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
          await childToken.approve(this.contract.address, withdrawalAmount);
          this.receipt = await this.contract.withdrawTo(childToken.address, deployer.address, withdrawalAmount);
        });

        withdraws(false);
      });
    });

    context('onERC20Received(address,address,uint256,bytes) receiver is from', function () {
      it('reverts if the token is not mapped (zero address)', async function () {
        await expect(this.unmappedTokenToZeroAddress.safeTransfer(this.contract.address, withdrawalAmount, EmptyByte))
          .to.be.revertedWithCustomError(this.contract, 'FxERC20TokenNotMapped')
          .withArgs(ZeroAddress);
      });

      it('reverts if the token is not mapped (wrong mapping)', async function () {
        await expect(this.unmappedTokenToWrongAddress.safeTransfer(this.contract.address, withdrawalAmount, EmptyByte))
          .to.be.revertedWithCustomError(this.contract, 'FxERC20TokenNotMapped')
          .withArgs(rootTokenWrongMapping);
      });

      context('when successful', function () {
        beforeEach(async function () {
          const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
          this.receipt = await childToken.safeTransfer(this.contract.address, withdrawalAmount, EmptyByte);
        });

        withdraws(true);
      });
    });

    context('onERC20Received(address,address,uint256,bytes) encoded receiver', function () {
      it('reverts if the token is not mapped (zero address)', async function () {
        await expect(
          this.unmappedTokenToZeroAddress.safeTransfer(
            this.contract.address,
            withdrawalAmount,
            ethers.utils.defaultAbiCoder.encode(['address'], [deployer.address])
          )
        )
          .to.be.revertedWithCustomError(this.contract, 'FxERC20TokenNotMapped')
          .withArgs(ZeroAddress);
      });

      it('reverts if the token is not mapped (wrong mapping)', async function () {
        await expect(
          this.unmappedTokenToWrongAddress.safeTransfer(
            this.contract.address,
            withdrawalAmount,
            ethers.utils.defaultAbiCoder.encode(['address'], [deployer.address])
          )
        )
          .to.be.revertedWithCustomError(this.contract, 'FxERC20TokenNotMapped')
          .withArgs(rootTokenWrongMapping);
      });

      context('when successful', function () {
        beforeEach(async function () {
          const childToken = (await ethers.getContractFactory('FxERC20MintBurn')).attach(await this.contract.rootToChildToken(rootToken));
          this.receipt = await childToken.safeTransfer(
            this.contract.address,
            withdrawalAmount,
            ethers.utils.defaultAbiCoder.encode(['address'], [deployer.address])
          );
        });

        withdraws(true);
      });
    });
  });
});
