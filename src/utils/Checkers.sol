// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Views } from "./Views.sol";
import { console } from "forge-std/console.sol";

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

    function _checkPurgeReq(address user, address receiver, address token, uint128 ngnsAmount) internal view {
        uint256 healthBps = userPositionHealth(user, token, 0);
        (CollateralConfig memory config,) = userConfig(user, token);
        if (healthBps > config.customLiqThreshold || healthBps > MIN_LIQ_THRESHOLD) revert PM__NotAllowed();
        if (msg.sender == user) revert PM__NotAllowed();

        bytes memory data = abi.encodeWithSignature("balanceOf(address)", msg.sender);
        (bool success, bytes memory res) = ngns.staticcall(data);
        if (!success) revert PM__BalanceReadFailed();
        uint256 liquidatorBalance = uint256(bytes32(res));
        if (liquidatorBalance < ngnsAmount) revert PM__InsufficientBurnAmount();
        if (receiver == address(0)) revert PM__InvalidAddress();
    }

    function _checkDepositAndMintReq(address token, uint256 amount) internal view {
        if (!isRegisteredCollateral(msg.sender, token)) {
            revert PM__UnregisteredCollateral();
        }
        if (amount <= 0) revert PM__ZeroAmount();
    }

    function _validatePositionHealth(
        CollateralConfig memory config,
        PositionConfig memory positions,
        address token,
        uint256 collateralToNgnValue,
        uint256 ngnsAmountToMint
    ) internal view {
        uint256 healthFactor = userPositionHealth(msg.sender, token, ngnsAmountToMint);
        if (healthFactor < config.customCollateralRatio) revert PM__UndercollateralizedPosition();
        uint256 debt = positions.mintedNgns;
        if (debt == 0) return;

        uint256 maxBorrow = (collateralToNgnValue * BPS_DENOMINATOR) / config.customCollateralRatio;
        if (debt + ngnsAmountToMint > maxBorrow) revert PM__BreachesCollateralRatio();
    }
}
