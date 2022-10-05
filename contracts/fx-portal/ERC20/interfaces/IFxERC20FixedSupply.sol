// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface IFxERC20FixedSupply {
    function initialize(
        address fxManager,
        address connectedToken,
        uint256 totalSupply,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        string memory uri,
        address initialOwner
    ) external;
}
