// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {FxRoot} from "@maticnetwork/fx-portal/contracts/FxRoot.sol";

contract FxRootMock is FxRoot {
    constructor(address stateSender) FxRoot(stateSender) {}
}
