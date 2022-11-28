// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {ERC20Storage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20Storage.sol";
import {FxERC20FixedSupply} from "./../../../fx-portal/ERC20/token/FxERC20FixedSupply.sol";

contract FxERC20FixedSupplyMock is FxERC20FixedSupply {
    using ERC20Storage for ERC20Storage.Layout;

    constructor(address[] memory holders, uint256[] memory allocations, IForwarderRegistry forwarderRegistry) FxERC20FixedSupply(forwarderRegistry) {
        ERC20Storage.layout().batchMint(holders, allocations);
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
