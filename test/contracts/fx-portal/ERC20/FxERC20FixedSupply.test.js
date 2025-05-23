const {expect} = require('chai');
const {ethers} = require('hardhat');
const {runBehaviorTests} = require('@animoca/ethereum-contract-helpers/src/test/run');
const {getDeployerAddress} = require('@animoca/ethereum-contract-helpers/src/test/accounts');
const {getForwarderRegistryAddress} = require('@animoca/ethereum-contracts/test/helpers/registries');
const {behavesLikeERC20} = require('@animoca/ethereum-contracts/test/contracts/token/ERC20/behaviors/ERC20.behavior');

const name = 'FxERC20FixedSupply';
const symbol = 'FxERC20FixedSupply';
const decimals = 18n;
const tokenURI = 'test';

const connectedToken = ethers.ZeroAddress;

const config = {
  immutable: {
    name: 'FxERC20FixedSupplyMock',
    ctorArguments: ['initialHolders', 'initialBalances', 'forwarderRegistry'],
    testMsgData: true,
  },
  defaultArguments: {
    forwarderRegistry: getForwarderRegistryAddress,
    initialHolders: [],
    initialBalances: [],
    initialAdmin: getDeployerAddress,
    initialOwner: getDeployerAddress,
  },
};

runBehaviorTests('FxERC20FixedSupply', config, function (deployFn) {
  const implementation = {
    name,
    symbol,
    decimals,
    tokenURI,
    errors: {
      // ERC20
      ApprovalToAddressZero: {custom: true, error: 'ERC20ApprovalToAddressZero', args: ['owner']},
      TransferToAddressZero: {custom: true, error: 'ERC20TransferToAddressZero', args: ['owner']},
      TransferExceedsBalance: {custom: true, error: 'ERC20InsufficientBalance', args: ['owner', 'balance', 'value']},
      TransferExceedsAllowance: {custom: true, error: 'ERC20InsufficientAllowance', args: ['owner', 'spender', 'allowance', 'value']},

      // ERC20Allowance
      AllowanceUnderflow: {custom: true, error: 'ERC20InsufficientAllowance', args: ['owner', 'spender', 'allowance', 'decrement']},
      AllowanceOverflow: {custom: true, error: 'ERC20AllowanceOverflow', args: ['owner', 'spender', 'allowance', 'increment']},

      // ERC20BatchTransfers
      BatchTransferValuesOverflow: {custom: true, error: 'ERC20BatchTransferValuesOverflow'},

      // ERC20SafeTransfers
      SafeTransferRejected: {custom: true, error: 'ERC20SafeTransferRejected', args: ['recipient']},

      // ERC2612
      PermitFromAddressZero: {custom: true, error: 'ERC20PermitFromAddressZero'},
      PermitExpired: {custom: true, error: 'ERC20PermitExpired', args: ['deadline']},
      PermitInvalid: {custom: true, error: 'ERC20PermitInvalidSignature'},

      // Misc
      InconsistentArrayLengths: {custom: true, error: 'InconsistentArrayLengths'},
      NotMinter: {custom: true, error: 'NotRoleHolder', args: ['role', 'account']},
      NotContractOwner: {custom: true, error: 'NotContractOwner', args: ['account']},
    },
    features: {
      // ERC165: true,
      EIP717: true, // unlimited approval
      AllowanceTracking: true,
    },
    interfaces: {
      ERC20: true,
      ERC20Detailed: true,
      ERC20Metadata: true,
      ERC20Allowance: true,
      ERC20BatchTransfer: true,
      ERC20Safe: true,
      ERC20Permit: true,
    },
    methods: {},
    deploy: async function (initialHolders, initialBalances, deployer) {
      const contract = await deployFn({initialHolders, initialBalances});
      await contract.initialize(deployer.address, connectedToken, 0, name, symbol, decimals, tokenURI, deployer.address);
      return contract;
    },
  };

  let deployer;

  before(async function () {
    [deployer] = await ethers.getSigners();
  });

  behavesLikeERC20(implementation);

  describe('fxManager()', function () {
    it('returns the correct value', async function () {
      const contract = await implementation.deploy([], [], deployer);
      expect(await contract.fxManager()).to.equal(deployer.address);
    });
  });
});
