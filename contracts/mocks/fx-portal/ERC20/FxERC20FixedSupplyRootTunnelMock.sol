// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {FxERC20FixedSupplyRootTunnel} from "./../../../fx-portal/ERC20/FxERC20FixedSupplyRootTunnel.sol";

contract FxERC20FixedSupplyRootTunnelMock is FxERC20FixedSupplyRootTunnel {
    constructor(
        address checkpointManager,
        address fxRoot,
        address fxERC20Token,
        IForwarderRegistry forwarderRegistry
    ) FxERC20FixedSupplyRootTunnel(checkpointManager, fxRoot, fxERC20Token, forwarderRegistry) {}

    function childToken(address rootToken) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(rootToken));
        return computedCreate2Address(salt, childTokenProxyCodeHash, fxChildTunnel);
    }

    function __processMessageFromChild(bytes calldata data) external {
        _processMessageFromChild(data);
    }
}
