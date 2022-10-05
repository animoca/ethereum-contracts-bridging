// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {ERC20Storage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20Storage.sol";
import {Create2} from "@maticnetwork/fx-portal/contracts/lib/Create2.sol";
import {ERC20Receiver} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20Receiver.sol";
import {FxBaseRootTunnel} from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";
import {FxTokenMapping} from "./../FxTokenMapping.sol";
import {ForwarderRegistryContext} from "@animoca/ethereum-contracts/contracts/metatx/ForwarderRegistryContext.sol";

/**
 * @title FxERC20RootTunnel
 */
abstract contract FxERC20RootTunnel is FxBaseRootTunnel, FxTokenMapping, ERC20Receiver, Create2, ForwarderRegistryContext {
    bytes32 public immutable childTokenProxyCodeHash;

    event TokenMappedERC20(address indexed rootToken, address indexed childToken);
    event FxWithdrawERC20(address indexed rootToken, address indexed childToken, address indexed userAddress, uint256 amount);
    event FxDepositERC20(address indexed rootToken, address indexed depositor, address indexed userAddress, uint256 amount);

    error FxERC20InvalidMappingOnExit(address childToken, address expectedRootToken, address actualRootToken);

    constructor(
        address checkpointManager,
        address fxRoot,
        address fxERC20Token,
        IForwarderRegistry forwarderRegistry
    ) FxBaseRootTunnel(checkpointManager, fxRoot) ForwarderRegistryContext(forwarderRegistry) {
        // compute child token proxy code hash
        childTokenProxyCodeHash = keccak256(minimalProxyCreationCode(fxERC20Token));
    }

    /**
     * @notice Map a token to enable its movement via the Fx Portal
     * @param rootToken address of token on root chain
     */
    function mapToken(address rootToken) public {
        if (rootToChildToken[rootToken] != address(0x0)) {
            return;
        }

        _mapToken(rootToken);

        // compute child token address before deployment using create2
        bytes32 salt = keccak256(abi.encodePacked(rootToken));
        address childToken = computedCreate2Address(salt, childTokenProxyCodeHash, fxChildTunnel);

        // add into mapped tokens
        rootToChildToken[rootToken] = childToken;
        emit TokenMappedERC20(rootToken, childToken);
    }

    /// @notice Handles the receipt of ERC20 tokens as a deposit request.
    /// @dev Note: this function is called by an {ERC20SafeTransfer} contract after a safe transfer.
    // @param operator The initiator of the safe transfer.
    /// @param from The previous tokens owner.
    /// @param value The amount of tokens transferred.
    /// @param data Empty if the receiver is the same as the tokens sender, else the abi-encoded address of the receiver.
    /// @return magicValue `bytes4(keccak256("onERC20Received(address,address,uint256,bytes)"))` (`0x4fc35859`) to accept, any other value to refuse.
    function onERC20Received(
        address,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4 magicValue) {
        address receiver = from;
        if (data.length != 0) {
            (receiver) = abi.decode(data, (address));
        }
        _deposit(msg.sender, from, receiver, value);
        return ERC20Storage.ERC20_RECEIVED;
    }

    function deposit(address rootToken, uint256 amount) external {
        address depositor = _msgSender();
        _depositFrom(rootToken, depositor, depositor, amount);
    }

    function depositTo(
        address rootToken,
        address receiver,
        uint256 amount
    ) external {
        _depositFrom(rootToken, _msgSender(), receiver, amount);
    }

    function _deposit(
        address rootToken,
        address depositor,
        address receiver,
        uint256 amount
    ) internal {
        mapToken(rootToken);
        _deposit(rootToken, amount);
        _sendDepositRequest(rootToken, depositor, receiver, amount);
    }

    function _depositFrom(
        address rootToken,
        address depositor,
        address receiver,
        uint256 amount
    ) internal {
        mapToken(rootToken);
        _depositFrom(rootToken, depositor, amount);
        _sendDepositRequest(rootToken, depositor, receiver, amount);
    }

    function _sendDepositRequest(
        address rootToken,
        address depositor,
        address receiver,
        uint256 amount
    ) internal {
        // DEPOSIT, encode(rootToken, depositor, user, amount)
        bytes memory message = abi.encode(DEPOSIT, abi.encode(rootToken, depositor, receiver, amount));
        _sendMessageToChild(message);
        emit FxDepositERC20(rootToken, depositor, receiver, amount);
    }

    // exit processor
    function _processMessageFromChild(bytes memory data) internal override {
        (address rootToken, address childToken, address to, uint256 amount) = abi.decode(data, (address, address, address, uint256));

        // validate mapping for root to child
        address mappedChildToken = rootToChildToken[rootToken];
        if (childToken != mappedChildToken) {
            revert FxERC20InvalidMappingOnExit(rootToken, childToken, mappedChildToken);
        }

        _withdraw(rootToken, to, amount);

        emit FxWithdrawERC20(rootToken, childToken, to, amount);
    }

    function _mapToken(address rootToken) internal virtual;

    /// @notice Deposits tokens to the child chain when transferred to this contract via onERC20Received function.
    /// @dev When this function is called, this contract has already become the owner of the tokens.
    function _deposit(address rootToken, uint256 amount) internal virtual;

    /// @notice Deposits tokens to the child chain from a withdrawer.
    /// @dev When this function is called, the withdrawer still owns the tokens.
    function _depositFrom(
        address rootToken,
        address depositor,
        uint256 amount
    ) internal virtual;

    /// @notice Withdraws the tokens received from the child chain.
    function _withdraw(
        address rootToken,
        address receiver,
        uint256 amount
    ) internal virtual;
}
