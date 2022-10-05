// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IStateSender} from "@maticnetwork/fx-portal/contracts/FxRoot.sol";

contract StateSenderMock is IStateSender {
    event StateSynced(uint256 indexed id, address indexed contractAddress, bytes data);

    function syncState(address receiver, bytes calldata data) external {
        emit StateSynced(0, receiver, data);
    }
}
