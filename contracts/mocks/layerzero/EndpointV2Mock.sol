// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

// contract EndpointV2Mock is ILayerZeroEndpointV2 {
contract EndpointV2Mock {
    // function quote(MessagingParams calldata _params, address _sender) external view returns (MessagingFee memory) {
    //     return MessagingFee(0, 0);
    // }

    // function send(
    //     MessagingParams calldata _params,
    //     address _refundAddress
    // ) external payable returns (MessagingReceipt memory) {
    //     return MessagingReceipt(0, 0, MessagingFee(0, 0));
    // }

    // function verify(Origin calldata _origin, address _receiver, bytes32 _payloadHash) external {
    //     emit PacketVerified(_origin, _receiver, _payloadHash);
    // }

    // function verifiable(Origin calldata _origin, address _receiver) external view returns (bool) {
    //     return true;
    // }

    // function initializable(Origin calldata _origin, address _receiver) external view returns (bool) {
    //     return true;
    // }

    // function lzReceive(
    //     Origin calldata _origin,
    //     address _receiver,
    //     bytes32 _guid,
    //     bytes calldata _message,
    //     bytes calldata _extraData
    // ) external payable {
    //     emit LzReceiveAlert(_receiver, msg.sender, _origin, _guid, gasleft(), msg.value, _message, _extraData, "");
    // }

    // // oapp can burn messages partially by calling this function with its own business logic if messages are verified in order
    // function clear(address _oapp, Origin calldata _origin, bytes32 _guid, bytes calldata _message) external {

    // }

    // function setLzToken(address _lzToken) external {
    //     emit LzTokenSet(_lzToken);
    // }

    // function lzToken() external view returns (address) {
    //     return address(0);
    // }

    // function nativeToken() external view returns (address) {
    //     return address(0);
    // }

    function setDelegate(address _delegate) external {}
}
