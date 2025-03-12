// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Base interface for an Fx child ERC20
interface IFxERC20 {
    /// @notice Returns the address of Fx Manager (FxChild).
    function fxManager() external returns (address);

    /// @notice Returns the address of the mapped root token.
    function connectedToken() external returns (address);
}
