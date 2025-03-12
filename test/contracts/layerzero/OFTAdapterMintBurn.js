const {ethers} = require('hardhat');
const {expect} = require('chai');
const {loadFixture} = require('@animoca/ethereum-contract-helpers/src/test/fixtures');
const {deployContract} = require('@animoca/ethereum-contract-helpers/src/test/deploy');
const {getForwarderRegistryAddress} = require('@animoca/ethereum-contracts/test/helpers/registries');

const tokenName = 'name';
const tokenSymbol = 'symbol';
const decimals = 18n;

describe('OFTAdapterMintBurn', function () {
  let deployer;

  before(async function () {
    [deployer, other] = await ethers.getSigners();
  });

  const fixture = async function () {
    const forwarderRegistryAddress = await getForwarderRegistryAddress();

    this.token = await deployContract('ERC20MintBurn', tokenName, tokenSymbol, decimals, forwarderRegistryAddress);
    const endpoint = await deployContract('EndpointV2Mock');
    this.contract = await deployContract('OFTAdapterMintBurnMock', await this.token.getAddress(), await endpoint.getAddress(), deployer.address);
    await this.token.grantRole(await this.token.MINTER_ROLE(), deployer.address);
    await this.token.grantRole(await this.token.MINTER_ROLE(), await this.contract.getAddress());
  };

  beforeEach(async function () {
    await loadFixture(fixture, this);
  });

  describe('token()', function () {
    it('is set to the address of the token contract', async function () {
      expect(await this.contract.token()).to.equal(await this.token.getAddress());
    });
  });

  describe('approvalRequired()', function () {
    it('returns true', async function () {
      expect(await this.contract.approvalRequired()).to.be.true;
    });
  });

  describe('_debit(address,uint256,uint256,uint32)', function () {
    const amount = ethers.parseEther('1');
    let receipt;

    it('reverts if the amount has some dust', async function () {
      const smallAmount = 100n;
      await expect(this.contract.debit(deployer.address, smallAmount, smallAmount, 0n))
        .to.be.revertedWithCustomError(this.contract, 'SlippageExceeded')
        .withArgs(0n, smallAmount);
    });

    context('when successful', function () {
      beforeEach(async function () {
        await this.token.mint(deployer.address, amount);
        await this.token.approve(await this.contract.getAddress(), amount);
        receipt = await this.contract.debit(deployer.address, amount, amount, 0n);
      });

      it('burns the specified amount from the sender', async function () {
        await expect(receipt).to.emit(this.token, 'Transfer').withArgs(deployer.address, ethers.ZeroAddress, amount);
      });

      it('returns the amount debited', async function () {
        await expect(receipt).to.emit(this.contract, 'Debit').withArgs(amount, amount);
      });
    });
  });

  describe('_credit(address,uint256,uint32)', function () {
    const amount = ethers.parseEther('1');
    let receipt;

    context('when successful', function () {
      beforeEach(async function () {
        await this.token.approve(await this.contract.getAddress(), amount);
        receipt = await this.contract.credit(deployer.address, amount, 0n);
      });

      it('mints the specified amount to the sender', async function () {
        await expect(receipt).to.emit(this.token, 'Transfer').withArgs(ethers.ZeroAddress, deployer.address, amount);
      });

      it('returns the amount credited', async function () {
        await expect(receipt).to.emit(this.contract, 'Credit').withArgs(amount);
      });
    });
  });
});
