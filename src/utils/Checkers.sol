// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Errors } from "./Errors.sol";
import { Views } from "./Views.sol";

abstract contract Checkers is Views, Errors {
    function _ensureNotLive(CollateralConfig memory config, bool register) internal pure {
        if (register) {
            if (config.isSupported == 1) {
                revert NGNSEngine__CollateralLive();
            }
        } else {
            if (config.totalMintedNgns > 0) {
                revert NGNSEngine__CollateralLive();
            }
        }
    }

    //  function _validatePositionHealth(address user, address token) internal view {
    //     uint256 debt = userMintedNGNS[user];
    //     if (debt == 0) return;

    //     AggregatorV3Interface oracle = AggregatorV3Interface(collateralConfigs[token].priceFeed);
    //     (, int256 price, , , ) = oracle.latestRoundData();

    //     // Collateral Value = (Amount * Price)
    //     uint256 collateralValue = (userCollateral[user][token] * uint256(price)) / 1e8; // Chainlink feeds use 8
    // decimals
    //     uint256 maxBorrow = (collateralValue * BPS_DENOMINATOR) / MIN_COLLATERAL_RATIO;
    //     if (debt > maxBorrow) revert NGNSEngine__BreachesCollateralRatio();
    // }
}
