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

    function _checkUpdateReq(address token, uint256 newRatio, uint256 newLiqThreshold, uint256 cRatio, bool isInDebt)
        internal
        view
        returns (bool)
    {
        if (!isRegisteredCollateral(msg.sender, token)) return false;

        if (isInDebt) revert PM__CannotModifyParametersWithActiveDebt();

        if (newRatio > 0) {
            if (newRatio < MIN_COLLATERAL_RATIO) {
                revert PM__InvalidCollateralRatio();
            }
        }

        if (newLiqThreshold > 0) {
            if (newLiqThreshold < MIN_LIQ_THRESHOLD) revert PM__InvalidLiqThreshold();
            if (newRatio > 0 && newLiqThreshold >= newRatio) revert PM__InvalidThresholdBuffer();
            if (newRatio == 0 && newLiqThreshold >= cRatio) revert PM__InvalidThresholdBuffer();
        }
        return true;
    }

    function _checkPurgeReq(
        address user,
        address receiver,
        address token,
        uint256 ngnsAmount,
        uint256 customLiqThreshold,
        uint256 currentDebt
    ) internal view returns (uint256) {
        uint256 healthBps = userPositionHealth(user, token, 0);
        if (healthBps > customLiqThreshold || healthBps > MIN_LIQ_THRESHOLD) revert PM__NotAllowed();
        if (msg.sender == user) revert PM__NotAllowed();
        if (currentDebt > MIN_DEBT_FLOOR) {
            if (ngnsAmount > currentDebt / 2) revert PM__CanOnlyLiquidatePartially();
        } else {
            ngnsAmount = currentDebt;
        }

        bytes memory data = abi.encodeWithSignature("balanceOf(address)", msg.sender);
        (bool success, bytes memory res) = ngns.staticcall(data);
        if (!success) revert PM__BalanceReadFailed();
        uint256 liquidatorBalance = uint256(bytes32(res));
        if (liquidatorBalance < ngnsAmount) revert PM__InsufficientBurnAmount();
        if (receiver == address(0)) revert PM__InvalidAddress();
        return ngnsAmount;
    }

    function _checkDepositAndMintReq(address token, uint256 amount, address priceFeed) internal view {
        // address priceFeed param makes it so that we have less sloads when loading positions and collateral config
        // isRegisteredCollateral() loads the same data openPosition() loads
        if (priceFeed == address(0)) {
            if (!isRegisteredCollateral(msg.sender, token)) {
                revert PM__UnregisteredCollateral();
            }
        } else {
            if (priceFeed == address(0)) {
                revert PM__UnregisteredCollateral();
            }
        }
        if (amount <= 0) revert PM__ZeroAmount();
    }

    function _checkWithdrawalReq(
        address token,
        address receiver,
        uint256 collateralDeposited,
        uint256 mintedNgns,
        uint256 customCollateralRatio
    ) internal view {
        // not calling userPositionHealth here, to prevent double sload
        uint256 nValue = ngnValue(token, uint256(collateralDeposited));
        uint256 health = mintedNgns > 0 ? (nValue * BPS_DENOMINATOR) / uint256(mintedNgns) : type(uint256).max;
        if (health < customCollateralRatio) revert PM__UndercollateralizedPosition();
        if (receiver == address(0)) revert PM__InvalidAddress();
    }

    function _checkFinalWithdrawalReq(address token, uint256 customCollateralRatio) internal view {
        uint256 health = userPositionHealth(msg.sender, token, 0);
        if (health < customCollateralRatio) revert PM__UndercollateralizedPosition();
    }

    function _validatePositionHealth(
        uint256 collateralToNgnValue,
        uint256 ngnsAmountToMint,
        uint256 mintedNgns,
        uint256 customCollateralRatio
    ) internal pure {
        uint256 healthFactor =
            (collateralToNgnValue * BPS_DENOMINATOR) / (uint256(mintedNgns) + ngnsAmountToMint);
        if (healthFactor < customCollateralRatio) revert PM__UndercollateralizedPosition();
        uint256 debt = mintedNgns;
        if (debt == 0) return;

        uint256 maxBorrow = (collateralToNgnValue * BPS_DENOMINATOR) / customCollateralRatio;
        if (debt + ngnsAmountToMint > maxBorrow) revert PM__BreachesCollateralRatio();
    }
}
