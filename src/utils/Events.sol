// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Events {
    event CollateralRegistered(address indexed user, address indexed token, address indexed priceFeed);
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
}
