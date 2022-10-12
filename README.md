# Animoca Ethereum Assets Bridging Contracts

[![NPM Package](https://img.shields.io/npm/v/@animoca/ethereum-contracts-bridging.svg)](https://www.npmjs.org/package/@animoca/ethereum-contracts-bridging)
[![Coverage Status](https://codecov.io/gh/animoca/ethereum-contracts-bridging/graph/badge.svg)](https://codecov.io/gh/animoca/ethereum-contracts-bridging)

Solidity contracts to manage bridging assets between blockchains.

## Audits

| Date | Scope | Commit | Package version | Auditor | Report |
| ---- | ----- | ------ | --------------- | ------- | ------ |
| -    | -     | -      | -               | -       | -      |

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
