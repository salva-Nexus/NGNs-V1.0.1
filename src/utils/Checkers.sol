// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Errors } from "./Errors.sol";
import { Views } from "./Views.sol";
import { CollateralOracle } from "@Oracles/CollateralOracle.sol";

abstract contract Checkers is Views, Errors, CollateralOracle {
    function _checkCollateralReq(address token, address feed, uint256 ratio, uint256 liqThreshold)
        internal
        view
    {
        if (isRegisteredCollateral(msg.sender, token)) {
            revert NGNSEngine__CollateralLive();
        }
        (, int256 price,,,) = priceFeed(feed);
        if (price <= 0) revert NGNSEngine__InvalidOracle();

        if (ratio < MIN_COLLATERAL_RATIO) {
            revert NGNSEngine__InvalidCollateralRatio();
        }

        if (liqThreshold < MIN_LIQ_THRESHOLD) {
            revert NGNSEngine__InvalidLiqThreshold();
        }
    }

    function _checkDepositReq(address token, uint256 amount) internal view {
        if (!isRegisteredCollateral(msg.sender, token)) {
            revert NGNSEngine__UnsupportedCollateral();
        }
        if (amount <= 0) revert NGNSEngine__ZeroAmount();
    }

    //  function _validatePositionHealth(address user, address token) internal view {
    //     uint256 debt = userMintedNGNS[user];
    //     if (debt == 0) return;

    //     AggregatorV3Interface oracle =
    // AggregatorV3Interface(collateralConfigs[token].priceFeed); (, int256 price, , , ) =
    // oracle.latestRoundData();

    //     // Collateral Value = (Amount * Price)
    //     uint256 collateralValue = (userCollateral[user][token] * uint256(price)) / 1e8; //
    // Chainlink feeds use 8 decimals
    //     uint256 maxBorrow = (collateralValue * BPS_DENOMINATOR) / MIN_COLLATERAL_RATIO;
    //     if (debt > maxBorrow) revert NGNSEngine__BreachesCollateralRatio();
    // }
}
