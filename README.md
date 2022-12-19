# Animoca Ethereum Assets Bridging Contracts

[![NPM Package](https://img.shields.io/npm/v/@animoca/ethereum-contracts-bridging.svg)](https://www.npmjs.org/package/@animoca/ethereum-contracts-bridging)
[![Coverage Status](https://codecov.io/gh/animoca/ethereum-contracts-bridging/graph/badge.svg)](https://codecov.io/gh/animoca/ethereum-contracts-bridging)

Solidity contracts to manage bridging assets between blockchains.

## Audits

| Date       | Scope                  | Commit                                                                                                                                           | Package version                                                                     | Auditor                                | Report                                                                                                                      |
| ---------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| 14/11/2022 | Full library (FxERC20) | [ac07a577f4c6545f2543f793fea6d4ee7b1ea928](https://github.com/animoca/ethereum-contracts-bridging/tree/ac07a577f4c6545f2543f793fea6d4ee7b1ea928) | [0.1.2](https://www.npmjs.com/package/@animoca/ethereum-contracts-bridging/v/0.1.2) | [Halborn](https://https://halborn.com) | [link](/audit/Animoca_SHRD_CATA_ERC20_Tokens_Polygon_ERC20_Bridging_Smart_Contract_Security_Audit_Report_Halborn_Final.pdf) |

## Compilation artifacts

The compilation artifacts, including the debug information, are available in the `artifacts` folder, both in the git repository and the release packages. These artifacts can be imported in dependents projects and used in tests or migration scripts with the following hardhat configuration:

```javascript
  external: {
    contracts: [
      {
        artifacts: 'node_modules/@animoca/ethereum-contracts-bridging/artifacts',
      },
    ],
  },
```

## Installation

To install the module in your project, add it as an npm dependency:

```bash
yarn add -D @animoca/ethereum-contracts hardhat
```

or

```bash
npm add --save-dev @animoca/ethereum-contracts hardhat
```

## Development

Install the dependencies:

```bash
yarn
```

Compile the contracts:

```bash
yarn compile
```

Run the tests:

```bash
yarn test
```

Run the tests (parallel mode):

```bash
yarn test-p
```

Run the coverage tests:

```bash
yarn coverage
```

Run the full pipeline (should be run before commiting code):

```bash
yarn run-all
```

See `package.json` for additional commands.

Note: this repository uses git lfs: the module should be installed before pushing changes.
