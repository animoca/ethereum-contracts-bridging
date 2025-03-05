// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IFxERC20} from "./../../token/ERC20/interfaces/IFxERC20.sol";
import {IFxERC20FixedSupply} from "./../../token/ERC20/interfaces/IFxERC20FixedSupply.sol";
import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FxERC20ChildTunnel} from "./FxERC20ChildTunnel.sol";

/// @title FxERC20FixedSupplyChildTunnel
/// @notice Fx child fixed supply ERC20 tunnel.
contract FxERC20FixedSupplyChildTunnel is FxERC20ChildTunnel {
    using SafeERC20 for IERC20;

    constructor(
        address fxChild,
        address childTokenLogic,
        IForwarderRegistry forwarderRegistry
    ) FxERC20ChildTunnel(fxChild, childTokenLogic, forwarderRegistry) {}

    /// @inheritdoc FxERC20ChildTunnel
    function _initializeChildToken(address rootToken, address childToken, bytes memory initArguments) internal virtual override {
        (uint256 totalSupply, string memory name, string memory symbol, uint8 decimals, string memory uri, address initialOwner) = abi.decode(
            initArguments,
            (uint256, string, string, uint8, string, address)
        );

        IFxERC20FixedSupply(childToken).initialize(
            address(this),
            rootToken,
            totalSupply,
            string(abi.encodePacked(name, SUFFIX_NAME)),
            string(abi.encodePacked(PREFIX_SYMBOL, symbol)),
            decimals,
            uri,
            initialOwner
        );
    }

    /// @inheritdoc FxERC20ChildTunnel
    /// @notice Unescrows the deposit amount from this contract.
    function _deposit(address childToken, address receiver, uint256 amount) internal virtual override {
        IERC20(childToken).safeTransfer(receiver, amount);
    }

    /// @inheritdoc FxERC20ChildTunnel
    /// @notice Tokens are already escrowed when coming through the onERC20Received function
    function _withdrawReceivedTokens(address childToken, uint256 amount) internal virtual override {}

    /// @inheritdoc FxERC20ChildTunnel
    /// @notice Escrows the withdrawal amount in this contract.
    function _withdrawTokensFrom(address childToken, address withdrawer, uint256 amount) internal virtual override {
        IERC20(childToken).safeTransferFrom(withdrawer, address(this), amount);
    }
}
