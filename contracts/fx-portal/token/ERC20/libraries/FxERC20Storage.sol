// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {ProxyInitialization} from "@animoca/ethereum-contracts/contracts/proxy/libraries/ProxyInitialization.sol";

library FxERC20Storage {
    using FxERC20Storage for FxERC20Storage.Layout;

    struct Layout {
        address manager;
        address rootToken;
    }

    bytes32 internal constant LAYOUT_STORAGE_SLOT = bytes32(uint256(keccak256("animoca.core.token.ERC20.FxERC20.storage")) - 1);
    bytes32 internal constant PROXY_INIT_PHASE_SLOT = bytes32(uint256(keccak256("animoca.core.token.ERC20.FxERC20.phase")) - 1);

    /// @notice Initializes the storage (proxied version).
    /// @notice Sets the proxy initialization phase to `1`.
    /// @dev Note: This function should be called ONLY in the init function of a proxied contract.
    /// @dev Reverts if the proxy initialization phase is set to `1` or above.
    /// @param fxManager_ The FX manager.
    /// @param connectedToken_ The root token address.
    function init(Layout storage s, address fxManager_, address connectedToken_) internal {
        ProxyInitialization.setPhase(PROXY_INIT_PHASE_SLOT, 1);
        s.manager = fxManager_;
        s.rootToken = connectedToken_;
    }

    function fxManager(Layout storage s) internal view returns (address) {
        return s.manager;
    }

    function connectedToken(Layout storage s) internal view returns (address) {
        return s.rootToken;
    }

    function layout() internal pure returns (Layout storage s) {
        bytes32 position = LAYOUT_STORAGE_SLOT;
        assembly {
            s.slot := position
        }
    }
}
