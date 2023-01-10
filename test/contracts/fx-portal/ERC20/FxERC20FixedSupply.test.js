const {expect} = require('chai');
const {ethers} = require('hardhat');
const {behavesLikeERC20} = require('@animoca/ethereum-contracts/test/contracts/token/ERC20/behaviors/ERC20.behavior');
const {getDeployerAddress, getForwarderRegistryAddress, runBehaviorTests} = require('@animoca/ethereum-contracts/test//helpers/run');
const {ZeroAddress} = require('@animoca/ethereum-contracts/src/constants');

const name = 'FxERC20FixedSupply';
const symbol = 'FxERC20FixedSupply';
const decimals = ethers.BigNumber.from('18');
const tokenURI = 'test';

const connectedToken = ZeroAddress;

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
    revertMessages: {
      // ERC20
      ApproveToZero: 'ERC20: approval to address(0)',
      TransferExceedsBalance: 'ERC20: insufficient balance',
      TransferToZero: 'ERC20: transfer to address(0)',
      TransferExceedsAllowance: 'ERC20: insufficient allowance',
      InconsistentArrays: 'ERC20: inconsistent arrays',
      SupplyOverflow: 'ERC20: supply overflow',

      // ERC20Allowance
      AllowanceUnderflow: 'ERC20: insufficient allowance',
      AllowanceOverflow: 'ERC20: allowance overflow',

      // ERC20BatchTransfers
      BatchTransferValuesOverflow: 'ERC20: values overflow',

      // ERC20SafeTransfers
      SafeTransferRejected: 'ERC20: safe transfer rejected',

      // ERC2612
      PermitFromZero: 'ERC20: permit from address(0)',
      PermitExpired: 'ERC20: expired permit',
      PermitInvalid: 'ERC20: invalid permit',

      // Admin
      NotMinter: "AccessControl: missing 'minter' role",
      NotContractOwner: 'Ownership: not the owner',
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
