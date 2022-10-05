// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface IFxERC20 {
    function fxManager() external returns (address);

    function connectedToken() external returns (address);
}
