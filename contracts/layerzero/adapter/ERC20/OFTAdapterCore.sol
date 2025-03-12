// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFTCore} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";

/// @title OFTAdapterCore
abstract contract OFTAdapterCore is OFTCore {
    address internal immutable _INNER_TOKEN;

    /// @notice Constructor for the OFTAdapterCore contract.
    /// @param innerToken The address of the ERC-20 token to be adapted.
    /// @param lzEndpoint The LayerZero endpoint address.
    /// @param delegate The delegate capable of making OApp configurations inside of the endpoint.
    constructor(
        address innerToken,
        address lzEndpoint,
        address delegate
    ) OFTCore(IERC20Metadata(innerToken).decimals(), lzEndpoint, delegate) Ownable(delegate) {
        _INNER_TOKEN = innerToken;
    }

    /// @inheritdoc IOFT
    function token() public view returns (address) {
        return _INNER_TOKEN;
    }

    /// @inheritdoc IOFT
    function approvalRequired() external pure virtual returns (bool) {
        return true;
    }
}
