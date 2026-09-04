// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Storage } from "../utils/Storage.sol";

abstract contract Views is Storage {
    function collateralConfig(address user, address token) public view returns (CollateralConfig memory) {
        bytes32 slot = _positionSlot(user, token);
        (address feed, uint48 ratio, uint48 liqThreshold) = _loadCollateralConfig(slot);
        return CollateralConfig({ priceFeed: feed, customCollateralRatio: ratio, customLiqThreshold: liqThreshold });
    }

    function positions(address user, address token) public view returns (PositionConfig memory) {
        bytes32 slot = _positionSlot(user, token);
        (uint128 totalCollateralDeposited, uint128 totalNgnsDebt) = _loadPositions(slot);
        return PositionConfig({ collateralDeposited: totalCollateralDeposited, mintedNgns: totalNgnsDebt });
    }

    function isRegisteredCollateral(address user, address token) public view returns (bool) {
        CollateralConfig memory config = collateralConfig(user, token);
        return config.priceFeed != address(0) ? true : false;
    }
    // function position(address user, address token)
    //     public
    //     view
    //     returns (uint256 totalCollateralDeposited, uint256 ngnsDebt)
    // {
    //     bytes32 slot = _positionSlot(user, token);
    //     return _loadPositions(slot);
    // }
}
