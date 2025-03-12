const {ethers} = require('hardhat');
const {expect} = require('chai');
const {loadFixture} = require('@animoca/ethereum-contract-helpers/src/test/fixtures');
const {deployContract} = require('@animoca/ethereum-contract-helpers/src/test/deploy');
const {getForwarderRegistryAddress} = require('@animoca/ethereum-contracts/test/helpers/registries');

const initialSupply = ethers.parseEther('1000');
const tokenName = 'name';
const tokenSymbol = 'symbol';
const decimals = 18n;

describe('OFTAdapterFixedSupply', function () {
  let deployer;

  before(async function () {
    [deployer, other] = await ethers.getSigners();
  });

  const fixture = async function () {
    const forwarderRegistryAddress = await getForwarderRegistryAddress();

    this.token = await deployContract(
      'ERC20FixedSupply',
      tokenName,
      tokenSymbol,
      decimals,
      [deployer.address],
      [initialSupply],
      forwarderRegistryAddress,
    );

    const endpoint = await deployContract('EndpointV2Mock');
    this.contract = await deployContract('OFTAdapterFixedSupplyMock', await this.token.getAddress(), await endpoint.getAddress(), deployer.address);
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
        await this.token.approve(await this.contract.getAddress(), amount);
        receipt = await this.contract.debit(deployer.address, amount, amount, 0n);
      });

      it('transfers the specified amount from the sender to the contract', async function () {
        await expect(receipt)
          .to.emit(this.token, 'Transfer')
          .withArgs(deployer.address, await this.contract.getAddress(), amount);
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
        await this.contract.debit(deployer.address, amount, amount, 0n);
        receipt = await this.contract.credit(deployer.address, amount, 0n);
      });

      it('transfers the specified amount from the contract to the sender', async function () {
        await expect(receipt)
          .to.emit(this.token, 'Transfer')
          .withArgs(await this.contract.getAddress(), deployer.address, amount);
      });

      it('returns the amount credited', async function () {
        await expect(receipt).to.emit(this.contract, 'Credit').withArgs(amount);
      });
    });
  });
});
