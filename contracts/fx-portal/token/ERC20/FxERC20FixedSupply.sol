// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {IFxERC20FixedSupply} from "./interfaces/IFxERC20FixedSupply.sol";
import {ERC20Storage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20Storage.sol";
import {FxERC20} from "./FxERC20.sol";

/// @title FxERC20FixedSupply
/// @notice Fx proxied child fixed supply ERC20.
contract FxERC20FixedSupply is FxERC20, IFxERC20FixedSupply {
    using ERC20Storage for ERC20Storage.Layout;

    constructor(IForwarderRegistry forwarderRegistry) FxERC20(forwarderRegistry) {}

    function initialize(
        address fxManager_,
        address connectedToken_,
        uint256 totalSupply,
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 tokenDecimals,
        string calldata uri,
        address initialOwner
    ) external {
        init(fxManager_, connectedToken_, tokenName, tokenSymbol, tokenDecimals, uri, initialOwner);
        ERC20Storage.layout().mint(fxManager_, totalSupply);
    }
}
