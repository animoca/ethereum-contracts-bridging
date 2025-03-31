# Changelog

## 2.0.1

### Bugfixes

- Downgraded to `chai@4` due to incompatibility with hardhat.
- Added package `resolutions` for `@ethersproject/**@5`, `elliptic`, `@openzeppelin/contracts`, `@openzeppelin/contracts-upgradeable`, `axios` and `cookie` to fix security issues in transitive dependencies.

## 2.0.0

### Breaking changes

- Upgraded to `@openzeppelin/contracts@5.2.0`.
- Upgraded to `solc@0.8.28`.
- Upgraded to `@animoca/ethereum-contracts@4.0.0`.
- Changed public variables casing for `FxERC20ChildTunnel`.`CHILD_TOKEN_LOGIC` and `FxERC20RootTunnel`.`CHILD_TOKEN_PROXY_CODE_HASH`.

### New features

- Added LayerZero OFT adapter `OFTAdapterFixedSupply` to be used with `ERC20FixedSupply` preset.
- Added LayerZero OFT adapter `OFTAdapterMintBurn` to be used with `ERC20MintBurn` preset.

### Improvements

- Updated to latest dependencies.

## 1.0.0

### Breaking changes

- Upgraded to `@openzeppelin/contracts@4.9.2`.
- Upgraded to `solc@0.8.19`.
- Upgraded to `@animoca/ethereum-contracts@2.0.0`.

### Improvements

- Updated to latest dependencies.

## 0.3.0

- Replace 0.2.0 mistakenly published as 0.2.4.

## 0.2.0

### Improvements

- Updated to latest dependencies.
- Fix versioning rules.

## 0.1.4

### Improvements

- Do not include audit reports in the node package.

## 0.1.3

### Bugfixes

- Fixed bugs when using yarn v2 or above.

### Improvements

- Updated to latest dependencies.

## 0.1.2

### Bugfixes

- Fixed out of sync messages encoding between FxERC20 tunnels.
- Added zero address checks on custom receiver for deposit/withdrawal on FxERC20 tunnels.

### Improvements

- Standardised events emitted by FxERC20 tunnels.

## 0.1.1

### Improvements

- Updated to latest dependencies.

## 0.1.0

- Initial release.
