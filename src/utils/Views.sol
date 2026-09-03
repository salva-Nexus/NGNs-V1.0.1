// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Storage } from "./Storage.sol";

abstract contract Views is Storage {
    function collateralConfig(address token) public view returns (CollateralConfig memory) {
        return collateralConfigs[token];
    }

    function isRegisteredCollateral(address token) public view returns (bool) {
        return collateralConfigs[token].isSupported == 1 ? true : false;
    }

    function position(address user, address token)
        public
        view
        returns (uint256 totalCollateralDeposited, uint256 ngnsDebt)
    {
        bytes32 slot = _positionSlot(user, token);
        return _loadPositions(slot);
    }
}
