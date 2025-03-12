// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {OFTAdapterCore} from "./OFTAdapterCore.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title OFTAdapterFixedSupply Contract
/// @dev OFTAdapter designed to work with an ERC20FixedSupply preset token contract.
contract OFTAdapterFixedSupply is OFTAdapterCore {
    using SafeERC20 for IERC20;

    constructor(address token, address lzEndpoint, address delegate) OFTAdapterCore(token, lzEndpoint, delegate) {}

    /// @notice Locks tokens from the sender's specified balance in this contract.
    /// @param from The address to debit from.
    /// @param amountLD The amount of tokens to send in local decimals.
    /// @param minAmountLD The minimum amount to send in local decimals.
    /// @param dstEid The destination chain ID.
    /// @return amountSentLD The amount sent in local decimals.
    /// @return amountReceivedLD The amount received in local decimals on the remote.
    function _debit(
        address from,
        uint256 amountLD,
        uint256 minAmountLD,
        uint32 dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(amountLD, minAmountLD, dstEid);
        IERC20(_innerToken).safeTransferFrom(from, address(this), amountSentLD);
    }

    /// @dev Credits tokens to the specified address.
    /// @param to The address to credit the tokens to.
    /// @param amountLD The amount of tokens to credit in local decimals.
    /// @dev srcEid The source chain ID.
    /// @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
    function _credit(address to, uint256 amountLD, uint32 /*srcEid*/) internal virtual override returns (uint256 amountReceivedLD) {
        IERC20(_innerToken).safeTransfer(to, amountLD);
        return amountLD;
    }
}
