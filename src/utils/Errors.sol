// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Errors {
    error NGNS__UnsupportedCollateral();
    error NGNS__InvalidOracle();
    error NGNS__BreachesCollateralRatio();
    error NGNS__InvalidCollateralRatio();
    error NGNS__CollateralLive();
    error NGNS__InvalidLiqThreshold();
    error NGNS__ZeroAmount();
    error NGNS__StalePrice();
    error NGNS__InvalidRound();
    error NGNS__InvalidThresholdBuffer();
    error NGNs__NotAllowed();
    error NGNs__InvalidAddress();
    error NGNS__TokenNotWhitelisted();
    error NGNS__InvalidPriceFeed();
}
