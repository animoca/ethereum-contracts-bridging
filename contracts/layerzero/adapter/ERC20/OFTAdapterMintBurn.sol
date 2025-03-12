// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20Mintable} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20Mintable.sol";
import {IERC20Burnable} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20Burnable.sol";
import {OFTAdapterCore} from "./OFTAdapterCore.sol";

/// @title OFTAdapterMintBurn Contract
/// @dev OFTAdapter designed to work with an ERC20MintBurn preset token contract.
contract OFTAdapterMintBurn is OFTAdapterCore {
    constructor(address token, address lzEndpoint, address delegate) OFTAdapterCore(token, lzEndpoint, delegate) {}

    /// @notice Burns tokens from the sender's specified balance in this contract.
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
        IERC20Burnable(_innerToken).burnFrom(from, amountSentLD);
    }

    /// @dev Mints tokens to the specified address.
    /// @param to The address to credit the tokens to.
    /// @param amountLD The amount of tokens to credit in local decimals.
    /// @dev srcEid The source chain ID.
    /// @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
    function _credit(address to, uint256 amountLD, uint32 /*srcEid*/) internal virtual override returns (uint256 amountReceivedLD) {
        IERC20Mintable(_innerToken).mint(to, amountLD);
        return amountLD;
    }
}
