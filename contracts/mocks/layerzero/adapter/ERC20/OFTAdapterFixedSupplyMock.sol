// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {OFTAdapterFixedSupply} from "./../../../../layerzero/adapter/ERC20/OFTAdapterFixedSupply.sol";

contract OFTAdapterFixedSupplyMock is OFTAdapterFixedSupply {
    event Debit(uint256 amountSentLD, uint256 amountReceivedLD);
    event Credit(uint256 amountReceivedLD);

    constructor(address token, address lzEndpoint, address delegate) OFTAdapterFixedSupply(token, lzEndpoint, delegate) {}

    function debit(address from, uint256 amountLD, uint256 minAmountLD, uint32 dstEid) external {
        (uint256 amountSentLD, uint256 amountReceivedLD) = _debit(from, amountLD, minAmountLD, dstEid);
        emit Debit(amountSentLD, amountReceivedLD);
    }

    function credit(address to, uint256 amountLD, uint32 srcEid) external {
        uint256 amountReceivedLD = _credit(to, amountLD, srcEid);
        emit Credit(amountReceivedLD);
    }
}
