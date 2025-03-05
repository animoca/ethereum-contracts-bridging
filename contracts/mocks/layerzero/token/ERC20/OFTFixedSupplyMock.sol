// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {OFTFixedSupply} from "./../../../../layerzero/token/ERC20/OFTFixedSupply.sol";

contract OFTFixedSupplyMock is OFTFixedSupply {
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address[] memory holders,
        uint256[] memory allocations,
        IForwarderRegistry forwarderRegistry,
        address lzEndpoint,
        address delegate
    ) OFTFixedSupply(tokenName, tokenSymbol, tokenDecimals, holders, allocations, forwarderRegistry, lzEndpoint, delegate) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
