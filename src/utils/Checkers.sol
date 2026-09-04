// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Errors } from "./Errors.sol";
import { Views } from "./Views.sol";

abstract contract Checkers is Views, Errors {
    function _checkCollateralReq(address token, uint256 price, uint256 ratio, uint256 liqThreshold) internal view {
        if (isRegisteredCollateral(msg.sender, token)) {
            revert NGNSEngine__CollateralLive();
        }

        if (price <= 0) revert NGNSEngine__InvalidOracle();

        if (ratio < MIN_COLLATERAL_RATIO) {
            revert NGNSEngine__InvalidCollateralRatio();
        }

        if (liqThreshold < MIN_LIQ_THRESHOLD) {
            revert NGNSEngine__InvalidLiqThreshold();
        }

        if (liqThreshold >= ratio) revert NGNSEngine__InvalidThresholdBuffer();
    }

    function _checkDepositReq(address token, uint256 amount) internal view {
        if (!isRegisteredCollateral(msg.sender, token)) {
            revert NGNSEngine__UnsupportedCollateral();
        }
        if (amount <= 0) revert NGNSEngine__ZeroAmount();
    }

    function _stalenessCheckNgn(uint256 lastUpdated) internal view {
        if (block.timestamp - lastUpdated > STALE_PRICE_THRESHOLD) {
            revert NGNSEngine__StalePrice();
        }
    }

    function _stalenessCheckChainlink(uint256 lastUpdated, uint80 roundId, uint80 answeredInRound) internal view {
        if (block.timestamp - lastUpdated > STALE_PRICE_THRESHOLD) {
            revert NGNSEngine__StalePrice();
        }

        if (answeredInRound < roundId) {
            revert NGNSEngine__StalePrice();
        }

        // 2. Check that a valid round exists
        if (roundId == 0) {
            revert NGNSEngine__InvalidRound();
        }
    }

    //  function _validatePositionHealth(address user, address token) internal view {
    //     CollateralConfig memory config = collateralConfig(user, token);
    //     PositionConfig memory position = positions(user, token);
    //     uint256 debt = position.mintedNgns;
    //     if (debt == 0) return;

    //     // Collateral Value = (Amount * Price)
    //     uint256 collateralValue = (userCollateral[user][token] * uint256(price)) / 1e8; //
    //     uint256 maxBorrow = (collateralValue * BPS_DENOMINATOR) / MIN_COLLATERAL_RATIO;
    //     if (debt > maxBorrow) revert NGNSEngine__BreachesCollateralRatio();
    // }

    // function positionHealth(CollateralConfig memory config, PositionConfig memory position)
    // public view returns (uint256 healthBps) { (, int256 price,,,) = priceFeed(config.priceFeed);
    // }
}
