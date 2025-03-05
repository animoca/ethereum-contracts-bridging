// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {ITokenRecovery} from "@animoca/ethereum-contracts/contracts/security/interfaces/ITokenRecovery.sol";
import {IERC20Metadata} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@animoca/ethereum-contracts/contracts/token/ERC721/interfaces/IERC721.sol";
import {ERC20Storage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20Storage.sol";
import {ERC20MetadataStorage} from "@animoca/ethereum-contracts/contracts/token/ERC20/libraries/ERC20MetadataStorage.sol";
import {TokenRecoveryLibrary} from "@animoca/ethereum-contracts/contracts/security/libraries/TokenRecoveryLibrary.sol";
import {ERC20} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Detailed} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20Detailed.sol";
import {ERC20Permit} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20Permit.sol";
import {ERC20SafeTransfers} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20SafeTransfers.sol";
import {ERC20BatchTransfers} from "@animoca/ethereum-contracts/contracts/token/ERC20/ERC20BatchTransfers.sol";
import {ForwarderRegistryContextBase} from "@animoca/ethereum-contracts/contracts/metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "@animoca/ethereum-contracts/contracts/metatx/ForwarderRegistryContext.sol";
import {OFTCore} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

abstract contract OFTFixedSupply is
    ITokenRecovery,
    IERC20Metadata,
    OFTCore,
    ERC20,
    ERC20Detailed,
    ERC20Permit,
    ERC20SafeTransfers,
    ERC20BatchTransfers,
    ForwarderRegistryContext
{
    using ERC20Storage for ERC20Storage.Layout;
    using ERC20MetadataStorage for ERC20MetadataStorage.Layout;

    /**
     * @dev Constructor for the OFT contract.
     * @param tokenName The name of the OFT.
     * @param tokenSymbol The symbol of the OFT.
     * @param lzEndpoint The LayerZero endpoint address.
     * @param delegate The delegate capable of making OApp configurations inside of the endpoint.
     */
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address[] memory holders,
        uint256[] memory allocations,
        IForwarderRegistry forwarderRegistry,
        address lzEndpoint,
        address delegate
    )
        ERC20Detailed(tokenName, tokenSymbol, tokenDecimals)
        ForwarderRegistryContext(forwarderRegistry)
        OFTCore(tokenDecimals, lzEndpoint, delegate)
        Ownable(msg.sender)
    {
        ERC20Storage.layout().batchMint(holders, allocations);
    }

    /**
     * @dev Retrieves the address of the underlying ERC20 implementation.
     * @return The address of the OFT token.
     *
     * @dev In the case of OFT, address(this) and erc20 are the same contract.
     */
    function token() public view returns (address) {
        return address(this);
    }

    /**
     * @notice Indicates whether the OFT contract requires approval of the 'token()' to send.
     * @return requiresApproval Needs approval of the underlying token implementation.
     *
     * @dev In the case of OFT where the contract IS the token, approval is NOT required.
     */
    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    /**
     * @dev Burns tokens from the sender's specified balance.
     * @param _from The address to debit the tokens from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        ERC20Storage.layout().burn(_from, amountSentLD);
    }

    /**
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
     */
    function _credit(address _to, uint256 _amountLD, uint32 /*_srcEid*/) internal virtual override returns (uint256 amountReceivedLD) {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        // @dev Default OFT mints on dst.
        ERC20Storage.layout().mint(_to, _amountLD);
        // @dev In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }

    /// @notice Sets the token URI.
    /// @dev Reverts if the sender is not the contract owner.
    /// @param uri The token URI.
    function setTokenURI(string calldata uri) external onlyOwner {
        ERC20MetadataStorage.layout().setTokenURI(uri);
    }

    /// @inheritdoc IERC20Metadata
    function tokenURI() external view returns (string memory) {
        return ERC20MetadataStorage.layout().tokenURI();
    }

    /// @inheritdoc ITokenRecovery
    /// @dev Reverts if the sender is not the contract owner.
    /// @dev Reverts with {InconsistentArrayLengths} `accounts` and `amounts` do not have the same length.
    /// @dev Reverts if one of the ETH transfers fails for any reason.
    function recoverETH(address payable[] calldata accounts, uint256[] calldata amounts) public virtual onlyOwner {
        TokenRecoveryLibrary.recoverETH(accounts, amounts);
    }

    /// @inheritdoc ITokenRecovery
    /// @dev Reverts if the sender is not the contract owner.
    /// @dev Reverts with {InconsistentArrayLengths} if `accounts`, `tokens` and `amounts` do not have the same length.
    /// @dev Reverts if one of the ERC20 transfers fails for any reason.
    function recoverERC20s(address[] calldata accounts, IERC20[] calldata tokens, uint256[] calldata amounts) public virtual onlyOwner {
        TokenRecoveryLibrary.recoverERC20s(accounts, tokens, amounts);
    }

    /// @inheritdoc ITokenRecovery
    /// @dev Reverts if the sender is not the contract owner.
    /// @dev Reverts with {InconsistentArrayLengths} if `accounts`, `contracts` and `amounts` do not have the same length.
    /// @dev Reverts if one of the ERC721 transfers fails for any reason.
    function recoverERC721s(address[] calldata accounts, IERC721[] calldata contracts, uint256[] calldata tokenIds) public virtual onlyOwner {
        TokenRecoveryLibrary.recoverERC721s(accounts, contracts, tokenIds);
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }
}
