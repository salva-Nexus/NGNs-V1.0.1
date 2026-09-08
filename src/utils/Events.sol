// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Events {
    event CollateralWhitelisted(address indexed token, address indexed priceFeed);
    event CollateralRegistered(address indexed user, address indexed token, address indexed priceFeed);
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event PositionOpened(address indexed user, address collateralToken, uint256 mintedNgnsAmount);
    event DebtSettled(address indexed user, address collateralToken, uint256 settledNgnsAmount);
    event Purged(
        address indexed user,
        address indexed collateralToken,
        address indexed liquidator,
        address receiver,
        uint256 debtPurged,
        uint256 collateralSeized,
        uint256 liqBonus
    );
    event CollateralConfigUpdated(
        address indexed user, address indexed token, uint48 customRatio, uint48 customLiqThreshold
    );
}
