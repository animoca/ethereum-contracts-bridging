// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {IFxERC20MintBurn} from "./interfaces/IFxERC20MintBurn.sol";
import {ERC20Storage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20Storage.sol";
import {ERC20MintableBase} from "@animoca/ethereum-contracts/contracts/token/ERC20/base/ERC20MintableBase.sol";
import {ERC20BurnableBase} from "@animoca/ethereum-contracts/contracts/token/ERC20/base/ERC20BurnableBase.sol";
import {AccessControlBase} from "@animoca/ethereum-contracts/contracts/access/base/AccessControlBase.sol";
import {FxERC20} from "./FxERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "@animoca/ethereum-contracts/contracts/metatx/base/ForwarderRegistryContextBase.sol";

/// @title FxERC20MintBurn
/// @notice Fx proxied child mintable burnable ERC20.
contract FxERC20MintBurn is FxERC20, ERC20MintableBase, ERC20BurnableBase, IFxERC20MintBurn, AccessControlBase {
    constructor(IForwarderRegistry forwarderRegistry) FxERC20(forwarderRegistry) {}

    function initialize(
        address fxManager_,
        address connectedToken_,
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 tokenDecimals,
        string calldata uri,
        address initialOwner
    ) external {
        init(fxManager_, connectedToken_, tokenName, tokenSymbol, tokenDecimals, uri, initialOwner);
        ERC20Storage.initERC20Mintable();
        ERC20Storage.initERC20Burnable();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(FxERC20, Context) returns (address) {
        return FxERC20._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(FxERC20, Context) returns (bytes calldata) {
        return FxERC20._msgData();
    }
}
