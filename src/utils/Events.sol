// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Events {
    event CollateralWhitelisted(address indexed token, address indexed priceFeed);
    event CollateralRegistered(address indexed user, address indexed token, address indexed priceFeed);
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event NgnsMinted(address indexed user, address collateralToken, uint256 mintedNgnsAmount);
}
