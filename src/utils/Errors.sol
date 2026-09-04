// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Errors {
    error NGNSEngine__UnsupportedCollateral();
    error NGNSEngine__InvalidOracle();
    error NGNSEngine__BreachesCollateralRatio();
    error NGNSEngine__InvalidCollateralRatio();
    error NGNSEngine__CollateralLive();
    error NGNSEngine__InvalidLiqThreshold();
    error NGNSEngine__ZeroAmount();
    error NGNSEngine__StalePrice();
    error NGNSEngine__InvalidRound();
    error NGNSEngine__InvalidThresholdBuffer();
}
