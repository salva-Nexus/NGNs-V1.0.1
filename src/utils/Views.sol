// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Storage } from "../utils/Storage.sol";
import { CollateralOracle } from "@Oracles/CollateralOracle.sol";
import { console } from "forge-std/console.sol";

abstract contract Views is Storage, CollateralOracle {
    function collateralConfig(address user, address token) public view returns (CollateralConfig memory) {
        bytes32 slot = _positionSlot(user, token);
        (address feed, uint48 ratio, uint48 liqThreshold) = _loadCollateralConfig(slot);
        return CollateralConfig({ priceFeed: feed, customCollateralRatio: ratio, customLiqThreshold: liqThreshold });
    }

    function positionConfig(address user, address token) public view returns (PositionConfig memory) {
        bytes32 slot = _positionSlot(user, token);
        (uint128 totalCollateralDeposited, uint128 totalNgnsDebt) = _loadPositionsConfig(slot);
        return PositionConfig({ collateralDeposited: totalCollateralDeposited, mintedNgns: totalNgnsDebt });
    }

    function userConfig(address user, address token)
        public
        view
        returns (CollateralConfig memory, PositionConfig memory)
    {
        bytes32 slot = _positionSlot(user, token);
        (address feed, uint48 ratio, uint48 liqThreshold) = _loadCollateralConfig(slot);
        (uint128 totalCollateralDeposited, uint128 totalNgnsDebt) = _loadPositionsConfig(slot);
        return (
            CollateralConfig({ priceFeed: feed, customCollateralRatio: ratio, customLiqThreshold: liqThreshold }),
            PositionConfig({ collateralDeposited: totalCollateralDeposited, mintedNgns: totalNgnsDebt })
        );
    }

    function userPositionHealth(address user, address token, uint256 debtAmount) public view returns (uint256) {
        PositionConfig memory positions = positionConfig(user, token);
        uint256 nValue = ngnValue(token, uint256(positions.collateralDeposited));

        return debtAmount == 0
            ? positions.mintedNgns > 0 ? (nValue * BPS_DENOMINATOR) / uint256(positions.mintedNgns) : type(uint256).max
            : (nValue * BPS_DENOMINATOR) / (uint256(positions.mintedNgns) + debtAmount);
    }

    function collateralAmountWithdrawable(address user, address token) public view returns (uint256) {
        (CollateralConfig memory config, PositionConfig memory positions) = userConfig(user, token);
        if (positions.collateralDeposited == 0) return 0;
        if (positions.mintedNgns == 0) return positions.collateralDeposited;
        uint256 nValueOfcValue = ngnValue(token, uint256(positions.collateralDeposited));
        uint256 lockedNValueOfCvalue =
            (uint256(positions.mintedNgns) * uint256(config.customCollateralRatio)) / BPS_DENOMINATOR;
        if (nValueOfcValue <= lockedNValueOfCvalue) return 0;
        uint256 excessNgn = nValueOfcValue - lockedNValueOfCvalue;
        console.log("excessNgn", excessNgn);
        (uint256 cValue,) = collateralValue(token, excessNgn);
        return cValue;
    }

    function isRegisteredCollateral(address user, address token) public view returns (bool) {
        CollateralConfig memory config = collateralConfig(user, token);
        return config.priceFeed != address(0);
    }
}
