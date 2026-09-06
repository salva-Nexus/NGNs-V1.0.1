// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Errors {
    error PM__UnsupportedCollateral();
    error PM__InvalidOracle();
    error PM__BreachesCollateralRatio();
    error PM__InvalidCollateralRatio();
    error PM__CollateralLive();
    error PM__InvalidLiqThreshold();
    error PM__ZeroAmount();
    error PM__StalePrice();
    error PM__InvalidRound();
    error PM__InvalidThresholdBuffer();
    error PM__InvalidTokenToFeedLength();
    error PM__InvalidAddress();
    error PM__TokenNotWhitelisted();
    error PM__InvalidPriceFeed();
}
