// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IFxERC20} from "./interfaces/IFxERC20.sol";
import {IFxERC20FixedSupply} from "./interfaces/IFxERC20FixedSupply.sol";
import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FxERC20ChildTunnel} from "./FxERC20ChildTunnel.sol";

/**
 * @title FxERC20FixedSupplyChildTunnel
 */
contract FxERC20FixedSupplyChildTunnel is FxERC20ChildTunnel {
    using SafeERC20 for IERC20;

    constructor(
        address fxChild,
        address childTokenLogic,
        IForwarderRegistry forwarderRegistry
    ) FxERC20ChildTunnel(fxChild, childTokenLogic, forwarderRegistry) {}

    function _initializeChildToken(
        address rootToken,
        address childToken,
        bytes memory initArguments
    ) internal virtual override {
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

    function _deposit(
        address childToken,
        address receiver,
        uint256 amount
    ) internal virtual override {
        IERC20(childToken).safeTransfer(receiver, amount);
    }

    function _withdraw(address childToken, uint256 amount) internal virtual override {
        // tokens are already escrowed when coming through the onERC20Received function
    }

    function _withdrawFrom(
        address childToken,
        address withdrawer,
        uint256 amount
    ) internal virtual override {
        IERC20(childToken).safeTransferFrom(withdrawer, address(this), amount);
    }
}
