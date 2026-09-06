// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IAdapter {
    function supply(address to, uint256 amount) external;
    function repay(address from, uint256 amount) external;
}
