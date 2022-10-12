// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {ERC20Storage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20Storage.sol";
import {Create2} from "@maticnetwork/fx-portal/contracts/lib/Create2.sol";
import {ERC20Receiver} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20Receiver.sol";
import {FxBaseRootTunnel} from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";
import {FxTokenMapping} from "./../../FxTokenMapping.sol";
import {ForwarderRegistryContext} from "@animoca/ethereum-contracts/contracts/metatx/ForwarderRegistryContext.sol";

/// @title FxERC20RootTunnel
/// @notice Base contract for an Fx root ERC20 tunnel.
abstract contract FxERC20RootTunnel is FxBaseRootTunnel, FxTokenMapping, ERC20Receiver, Create2, ForwarderRegistryContext {
    bytes32 public immutable childTokenProxyCodeHash;

    /// @notice Emitted when an ERC20 token has been mapped.
    /// @param rootToken The root ERC20 token.
    /// @param childToken The child ERC20 token.
    event TokenMappedERC20(address indexed rootToken, address indexed childToken);

    /// @notice Emitted when some ERC20 token has been withdrawn.
    /// @param rootToken The root ERC20 token.
    /// @param childToken The child ERC20 token.
    /// @param userAddress The withdrawer address.
    /// @param amount The withdrawal amount.
    event FxWithdrawERC20(address indexed rootToken, address indexed childToken, address indexed userAddress, uint256 amount);

    /// @notice Emitted when some ERC20 token has been deposited.
    /// @param rootToken The root ERC20 token.
    /// @param depositor The depositor address.
    /// @param userAddress The recipient address.
    /// @param amount The deposit amount.
    event FxDepositERC20(address indexed rootToken, address indexed depositor, address indexed userAddress, uint256 amount);

    /// @notice Thrown when a deposit request refers to an invalid token mapping.
    /// @param childToken The child token.
    /// @param expectedRootToken The expected root token.
    /// @param actualRootToken The actual root token.
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

    /// @notice Map a token to enable its movement via the Fx Portal
    /// @param rootToken address of token on root chain
    function mapToken(address rootToken) public {
        if (rootToChildToken[rootToken] != address(0x0)) {
            return;
        }

        // send the mapping request to the child chain
        _sendMessageToChild(abi.encode(MAP_TOKEN, abi.encode(rootToken, _encodeChildTokenInitArgs(rootToken))));

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

    /// @notice Deposits an `amount` of `rootToken` by and for the message sender.
    /// @notice Note: Approval for `amount` of `rootToken` must have been previously given to this contract.
    /// @dev Reverts if the token transfer fails for any reason.
    /// @param rootToken The ERC20 root token.
    /// @param amount The amount of tokens to deposit.
    function deposit(address rootToken, uint256 amount) external {
        address depositor = _msgSender();
        _depositFrom(rootToken, depositor, depositor, amount);
    }

    /// @notice Deposits an `amount` of `rootToken` by the message sender and for a `receiver`.
    /// @notice Note: Approval for `amount` of `rootToken` must have been previously given to this contract.
    /// @dev Reverts with `FxERC20TokenNotMapped` if `childToken has not been deployed through a mapping request.
    /// @dev Reverts if the token transfer fails for any reason.
    /// @param rootToken The ERC20 root token.
    /// @param receiver The account receiving the deposit.
    /// @param amount The amount of tokens to deposit.
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

    /// @notice Returns the abi-encoded arguments for the Fx child token initialization function.
    /// @param rootToken The root token address.
    function _encodeChildTokenInitArgs(address rootToken) internal virtual returns (bytes memory);

    /// @notice Deposits tokens to the child chain when transferred to this contract via onERC20Received function.
    /// @dev When this function is called, this contract has already become the owner of the tokens.
    /// @param rootToken The root token address.
    /// @param amount The token amount to deposit.
    function _deposit(address rootToken, uint256 amount) internal virtual;

    /// @notice Deposits tokens to the child chain from a withdrawer.
    /// @dev When this function is called, the withdrawer still owns the tokens.
    /// @param rootToken The root token address.
    /// @param depositor The depositor address.
    /// @param amount The token amount to deposit.
    function _depositFrom(
        address rootToken,
        address depositor,
        uint256 amount
    ) internal virtual;

    /// @notice Withdraws the tokens received from the child chain.
    /// @param rootToken The root token address.
    /// @param receiver The receiver address.
    /// @param amount The token amount to deposit.
    function _withdraw(
        address rootToken,
        address receiver,
        uint256 amount
    ) internal virtual;
}
