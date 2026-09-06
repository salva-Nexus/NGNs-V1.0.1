// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Views } from "./Views.sol";

abstract contract Checkers is Views {
    function _checkCollateralReq(address token, uint256 price, uint256 ratio, uint256 liqThreshold) internal view {
        if (isRegisteredCollateral(msg.sender, token)) {
            revert PM__CollateralLive();
        }

        if (price <= 0) revert PM__InvalidOracle();

        if (ratio < MIN_COLLATERAL_RATIO) {
            revert PM__InvalidCollateralRatio();
        }

        if (liqThreshold < MIN_LIQ_THRESHOLD) {
            revert PM__InvalidLiqThreshold();
        }

        if (liqThreshold >= ratio) revert PM__InvalidThresholdBuffer();
    }

    function _checkDepositAndMintReq(address token, uint256 amount) internal view {
        if (!isRegisteredCollateral(msg.sender, token)) {
            revert PM__UnsupportedCollateral();
        }
        if (amount <= 0) revert PM__ZeroAmount();
    }

    function _validatePositionHealth(
        CollateralConfig memory config,
        PositionConfig memory positions,
        uint256 ngnValue,
        uint256 ngnsAmountToMint
    ) internal pure {
        uint256 debt = positions.mintedNgns;
        if (debt == 0) return;

        uint256 collateralValue = ngnValue;
        uint256 maxBorrow = (collateralValue * BPS_DENOMINATOR) / config.customCollateralRatio;
        if (debt + ngnsAmountToMint > maxBorrow) revert PM__BreachesCollateralRatio();
    }
}
