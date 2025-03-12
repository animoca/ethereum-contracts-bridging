// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Initialization interface for an Fx child mintable and burnable ERC20
interface IFxERC20MintBurn {
    function initialize(
        address fxManager,
        address connectedToken,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        string memory uri,
        address initialOwner
    ) external;
}
