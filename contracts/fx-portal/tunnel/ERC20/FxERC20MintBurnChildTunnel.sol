// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IFxERC20MintBurn} from "./../../token/ERC20/interfaces/IFxERC20MintBurn.sol";
import {IERC20Mintable} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20Mintable.sol";
import {IERC20Burnable} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20Burnable.sol";
import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {FxERC20ChildTunnel} from "./FxERC20ChildTunnel.sol";

/// @title FxERC20MintBurnChildTunnel
/// @notice Fx child mintable burnable ERC20 tunnel.
contract FxERC20MintBurnChildTunnel is FxERC20ChildTunnel {
    constructor(
        address fxChild,
        address childTokenLogic,
        IForwarderRegistry forwarderRegistry
    ) FxERC20ChildTunnel(fxChild, childTokenLogic, forwarderRegistry) {}

    /// @inheritdoc FxERC20ChildTunnel
    function _initializeChildToken(address rootToken, address childToken, bytes memory initArguments) internal virtual override {
        (string memory name, string memory symbol, uint8 decimals, string memory uri, address initialOwner) = abi.decode(
            initArguments,
            (string, string, uint8, string, address)
        );

        IFxERC20MintBurn(childToken).initialize(
            address(this),
            rootToken,
            string(abi.encodePacked(name, SUFFIX_NAME)),
            string(abi.encodePacked(PREFIX_SYMBOL, symbol)),
            decimals,
            uri,
            initialOwner
        );
    }

    /// @inheritdoc FxERC20ChildTunnel
    /// @notice Mints the deposit amount.
    function _deposit(address childToken, address receiver, uint256 amount) internal virtual override {
        IERC20Mintable(childToken).mint(receiver, amount);
    }

    /// @inheritdoc FxERC20ChildTunnel
    /// @notice Burns the withdrawal amount.
    function _withdrawReceivedTokens(address childToken, uint256 amount) internal virtual override {
        IERC20Burnable(childToken).burn(amount);
    }

    /// @inheritdoc FxERC20ChildTunnel
    /// @notice Burns the withdrawal amount.
    function _withdrawTokensFrom(address childToken, address withdrawer, uint256 amount) internal virtual override {
        IERC20Burnable(childToken).burnFrom(withdrawer, amount);
    }
}
