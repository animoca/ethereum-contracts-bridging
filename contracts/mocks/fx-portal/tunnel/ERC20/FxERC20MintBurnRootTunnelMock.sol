// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {FxERC20MintBurnRootTunnel} from "./../../../../fx-portal/tunnel/ERC20/FxERC20MintBurnRootTunnel.sol";

contract FxERC20MintBurnRootTunnelMock is FxERC20MintBurnRootTunnel {
    constructor(
        address checkpointManager,
        address fxRoot,
        address fxERC20Token,
        IForwarderRegistry forwarderRegistry
    ) FxERC20MintBurnRootTunnel(checkpointManager, fxRoot, fxERC20Token, forwarderRegistry) {}

    function childToken(address rootToken) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(rootToken));
        return computedCreate2Address(salt, childTokenProxyCodeHash, fxChildTunnel);
    }

    function __processMessageFromChild(bytes calldata data) external {
        _processMessageFromChild(data);
    }
}
