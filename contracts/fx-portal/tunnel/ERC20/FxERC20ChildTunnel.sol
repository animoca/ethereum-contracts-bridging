// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IFxERC20} from "./../../token/ERC20/interfaces/IFxERC20.sol";
import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC20Storage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20Storage.sol";
import {FxBaseChildTunnel} from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseChildTunnel.sol";
import {FxTokenMapping} from "./../FxTokenMapping.sol";
import {FxERC20TunnelEvents} from "./FxERC20TunnelEvents.sol";
import {ERC20Receiver} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20Receiver.sol";
import {Create2} from "@maticnetwork/fx-portal/contracts/lib/Create2.sol";
import {ForwarderRegistryContext} from "@animoca/ethereum-contracts/contracts/metatx/ForwarderRegistryContext.sol";

/// @title FxERC20ChildTunnel
/// @notice Base contract for an Fx child ERC20 tunnel.
abstract contract FxERC20ChildTunnel is FxBaseChildTunnel, FxTokenMapping, FxERC20TunnelEvents, ERC20Receiver, Create2, ForwarderRegistryContext {
    using Address for address;

    string public constant SUFFIX_NAME = " (Polygon)";
    string public constant PREFIX_SYMBOL = "p";

    address public immutable childTokenLogic;

    /// @notice Thrown during construction if the provided child token logic address is not a deployed contract.
    error FxERC20ChildTokenLogicNotContract();

    /// @notice Thrown during a withdrawal if the requested child token withdrawal was not mapped from a root token.
    error FxERC20TokenNotMapped();

    /// @notice Thrown during a mapping request if the root token already has a mapping.
    /// @param rootToken The mapped root token.
    /// @param childToken The mapped child token.
    error FxERC20TokenAlreadyMapped(address rootToken, address childToken);

    /// @notice Thrown if a sync request is of an unrecognized type.
    /// @param syncType The unrecognized sync type.
    error FxERC20InvalidSyncType(bytes32 syncType);

    /// @notice Thrown if a withdrawal recipient is the zero address.
    error FxERC20InvalidWithdrawalAddress();

    /// @dev Reverts with `FxERC20ChildTokenLogicNotContract` if `childTokenLogic_` is not a contract.
    constructor(
        address fxChild,
        address childTokenLogic_,
        IForwarderRegistry forwarderRegistry
    ) FxBaseChildTunnel(fxChild) ForwarderRegistryContext(forwarderRegistry) {
        if (!childTokenLogic_.isContract()) {
            revert FxERC20ChildTokenLogicNotContract();
        }
        childTokenLogic = childTokenLogic_;
    }

    /// @notice Handles the receipt of ERC20 tokens as a withdrawal request.
    /// @dev Note: this function is called by an {ERC20SafeTransfer} contract after a safe transfer.
    /// @dev Reverts with `FxERC20InvalidWithdrawalAddress` if `receiver` is encoded in `data` and is the zero address.
    /// @dev Reverts with `FxERC20TokenNotMapped` if the child token (msg.sender) has not been deployed through a mapping request.
    // @param operator The initiator of the safe transfer.
    /// @param from The previous tokens owner.
    /// @param value The amount of tokens transferred.
    /// @param data Empty if the receiver is the same as the tokens sender, else the abi-encoded address of the receiver.
    /// @return magicValue `bytes4(keccak256("onERC20Received(address,address,uint256,bytes)"))` (`0x4fc35859`) to accept, any other value to refuse.
    function onERC20Received(address, address from, uint256 value, bytes calldata data) external returns (bytes4 magicValue) {
        address receiver = from;
        if (data.length != 0) {
            (receiver) = abi.decode(data, (address));
            if (receiver == address(0)) {
                revert FxERC20InvalidWithdrawalAddress();
            }
        }
        _withdraw(msg.sender, from, receiver, value);
        _withdrawReceivedTokens(msg.sender, value);
        return ERC20Storage.ERC20_RECEIVED;
    }

    /// @notice Requests the withdrawal of an `amount` of `childToken` by and for the message sender.
    /// @notice Note: Approval for `amount` of `childToken` must have been previously given to this contract.
    /// @dev Reverts with `FxERC20TokenNotMapped` if `childToken` has not been deployed through a mapping request.
    /// @dev Reverts if the token transfer fails for any reason.
    /// @param childToken The ERC20 child token which has previously been deployed as a mapping for a root token.
    /// @param amount The amount of tokens to withdraw.
    function withdraw(address childToken, uint256 amount) external {
        address withdrawer = _msgSender();
        _withdraw(childToken, withdrawer, withdrawer, amount);
        _withdrawTokensFrom(childToken, withdrawer, amount);
    }

    /// @notice Requests the withdrawal of an `amount` of `childToken` by the message sender and for a `receiver`.
    /// @notice Note: Approval for `amount` of `childToken` must have been previously given to this contract.
    /// @dev Reverts with `FxERC20InvalidWithdrawalAddress` if `receiver` is the zero address.
    /// @dev Reverts with `FxERC20TokenNotMapped` if `childToken` has not been deployed through a mapping request.
    /// @dev Reverts if the token transfer fails for any reason.
    /// @param childToken The ERC20 child token which has previously been deployed as a mapping for a root token.
    /// @param receiver The account receiving the withdrawal.
    /// @param amount The amount of tokens to withdraw.
    function withdrawTo(address childToken, address receiver, uint256 amount) external {
        if (receiver == address(0)) {
            revert FxERC20InvalidWithdrawalAddress();
        }
        address withdrawer = _msgSender();
        _withdraw(childToken, withdrawer, receiver, amount);
        _withdrawTokensFrom(childToken, withdrawer, amount);
    }

    /// @notice Processes a message coming from the root chain.
    /// @dev Reverts with `FxERC20InvalidSyncType` if the sync type is not DEPOSIT or MAP_TOKEN.
    function _processMessageFromRoot(uint256 /* stateId */, address sender, bytes memory data) internal override validateSender(sender) {
        // decode incoming data
        (bytes32 syncType, bytes memory syncData) = abi.decode(data, (bytes32, bytes));

        if (syncType == DEPOSIT) {
            _syncDeposit(syncData);
        } else if (syncType == MAP_TOKEN) {
            _mapToken(syncData);
        } else {
            revert FxERC20InvalidSyncType(syncType);
        }
    }

    function _syncDeposit(bytes memory syncData) internal {
        (address rootToken, address depositor, address receiver, uint256 amount) = abi.decode(syncData, (address, address, address, uint256));
        address childToken = rootToChildToken[rootToken];

        // deposit tokens
        _deposit(childToken, receiver, amount);

        emit FxERC20Deposit(rootToken, childToken, depositor, receiver, amount);
    }

    function _withdraw(address childToken, address withdrawer, address receiver, uint256 amount) internal {
        address rootToken = IFxERC20(childToken).connectedToken();
        if (rootToken == address(0x0) || childToken != rootToChildToken[rootToken]) {
            revert FxERC20TokenNotMapped();
        }

        _sendMessageToRoot(abi.encode(rootToken, childToken, withdrawer, receiver, amount));
        emit FxERC20Withdrawal(rootToken, childToken, withdrawer, receiver, amount);
    }

    function _mapToken(bytes memory syncData) internal returns (address childToken) {
        (address rootToken, bytes memory initArguments) = abi.decode(syncData, (address, bytes));

        // get root to child token
        childToken = rootToChildToken[rootToken];

        // check if it's already mapped
        if (childToken != address(0)) {
            revert FxERC20TokenAlreadyMapped(rootToken, childToken);
        }

        // deploy new child token
        bytes32 salt = keccak256(abi.encodePacked(rootToken));
        childToken = createClone(salt, childTokenLogic);

        _initializeChildToken(rootToken, childToken, initArguments);

        // map the token
        rootToChildToken[rootToken] = childToken;
        emit FxERC20TokenMapping(rootToken, childToken);
    }

    /// @notice Calls the initialization sequence of a child token.
    /// @param rootToken The root token address.
    /// @param childToken The child token address.
    /// @param initArguments The abi-encoded child token initialization arguments.
    function _initializeChildToken(address rootToken, address childToken, bytes memory initArguments) internal virtual;

    /// @notice Deposits the tokens received from the root chain.
    /// @param childToken The child token address.
    /// @param receiver The deposit receiver address.
    /// @param amount The deposit amount.
    function _deposit(address childToken, address receiver, uint256 amount) internal virtual;

    /// @notice Withdraws tokens to the root chain when transferred to this contract via onERC20Received function.
    /// @dev When this function is called, this contract has already become the owner of the tokens.
    /// @param childToken The child token address.
    /// @param amount The withdrawal amount.
    function _withdrawReceivedTokens(address childToken, uint256 amount) internal virtual;

    /// @notice Withdraws tokens to the root chain from a withdrawer.
    /// @dev When this function is called, the withdrawer still owns the tokens.
    /// @param childToken The child token address.
    /// @param withdrawer The withdrawer address.
    /// @param amount The withdrawal amount.
    function _withdrawTokensFrom(address childToken, address withdrawer, uint256 amount) internal virtual;
}
