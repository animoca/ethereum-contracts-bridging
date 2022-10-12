// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {IFxERC20} from "./interfaces/IFxERC20.sol";
import {ERC20Storage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20Storage.sol";
import {ERC20DetailedStorage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20DetailedStorage.sol";
import {ERC20MetadataStorage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20MetadataStorage.sol";
import {ERC20PermitStorage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20PermitStorage.sol";
import {FxERC20Storage} from "./libraries/FxERC20Storage.sol";
import {ContractOwnershipStorage} from "@animoca/ethereum-contracts/contracts/access/libraries/ContractOwnershipStorage.sol";
import {ERC20Base} from "@animoca/ethereum-contracts/contracts/token/ERC20/base/ERC20Base.sol";
import {ERC20DetailedBase} from "@animoca/ethereum-contracts/contracts/token/ERC20/base/ERC20DetailedBase.sol";
import {ERC20MetadataBase} from "@animoca/ethereum-contracts/contracts/token/ERC20/base/ERC20MetadataBase.sol";
import {ERC20PermitBase} from "@animoca/ethereum-contracts/contracts/token/ERC20/base/ERC20PermitBase.sol";
import {ERC20SafeTransfersBase} from "@animoca/ethereum-contracts/contracts/token/ERC20/base/ERC20SafeTransfersBase.sol";
import {ERC20BatchTransfersBase} from "@animoca/ethereum-contracts/contracts/token/ERC20/base/ERC20BatchTransfersBase.sol";
import {InterfaceDetection} from "@animoca/ethereum-contracts/contracts/introspection/InterfaceDetection.sol";
import {ContractOwnershipBase} from "@animoca/ethereum-contracts/contracts/access/base/ContractOwnershipBase.sol";
import {TokenRecoveryBase} from "@animoca/ethereum-contracts/contracts/security/base/TokenRecoveryBase.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "@animoca/ethereum-contracts/contracts/metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "@animoca/ethereum-contracts/contracts/metatx/ForwarderRegistryContext.sol";

/// @title FxERC20
/// @notice Base contract for a proxied Fx child ERC20.
abstract contract FxERC20 is
    ERC20Base,
    ERC20DetailedBase,
    ERC20MetadataBase,
    ERC20PermitBase,
    ERC20SafeTransfersBase,
    ERC20BatchTransfersBase,
    InterfaceDetection,
    ContractOwnershipBase,
    TokenRecoveryBase,
    IFxERC20,
    ForwarderRegistryContext
{
    using ERC20DetailedStorage for ERC20DetailedStorage.Layout;
    using ERC20MetadataStorage for ERC20MetadataStorage.Layout;
    using ERC20PermitStorage for ERC20PermitStorage.Layout;
    using FxERC20Storage for FxERC20Storage.Layout;
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    constructor(IForwarderRegistry forwarderRegistry) ForwarderRegistryContext(forwarderRegistry) {}

    function init(
        address fxManager_,
        address connectedToken_,
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 tokenDecimals,
        string calldata uri,
        address initialOwner
    ) internal {
        ERC20Storage.init();
        ERC20DetailedStorage.layout().proxyInit(tokenName, tokenSymbol, tokenDecimals);
        ERC20MetadataStorage.init();
        ERC20MetadataStorage.layout().setTokenURI(uri);
        ERC20PermitStorage.init();
        ERC20Storage.initERC20BatchTransfers();
        ERC20Storage.initERC20SafeTransfers();
        FxERC20Storage.layout().init(fxManager_, connectedToken_);
        ContractOwnershipStorage.layout().proxyInit(initialOwner);
    }

    /// @inheritdoc IFxERC20
    function fxManager() external view returns (address) {
        return FxERC20Storage.layout().fxManager();
    }

    /// @inheritdoc IFxERC20
    function connectedToken() external view returns (address) {
        return FxERC20Storage.layout().connectedToken();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }
}
