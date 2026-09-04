// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Events } from "./utils/Events.sol";
import { INGNOracle } from "@INGNOracle/INGNOracle.sol";
import { INGNS } from "@INGNS/INGNS.sol";
import { CollateralOracle } from "@Oracles/CollateralOracle.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NGNSEngine is CollateralOracle, Events {
    using SafeERC20 for IERC20;

    constructor(address ngnsTokenAddress, address priceFeedAddress) {
        ngns = ngnsTokenAddress;
        ngnPriceFeed = priceFeedAddress;
    }

    /// @notice Permissionless Collateral Registration via Chainlink Feed Check
    function registerCollateral(address token, address priceFeedAddress, uint48 ratio, uint48 liqThreshold) external {
        (, int256 price,,,) = priceFeed(priceFeedAddress);
        _checkCollateralReq(token, uint256(price), uint256(ratio), uint256(liqThreshold));
        _storeCollateralConfig(token, priceFeedAddress, ratio, liqThreshold);
        emit CollateralRegistered(msg.sender, token, priceFeedAddress);
    }

    function depositCollateral(address token, uint128 collateralAmount) external {
        CollateralConfig memory config = collateralConfig(msg.sender, token);
        _checkDepositReq(token, uint256(collateralAmount));
        uint256 ngnValue = getNgnValue(token, config.priceFeed, uint256(collateralAmount));
        _storeCollateralPosition(token, uint128(ngnValue), 1);
        IERC20(token).safeTransferFrom(msg.sender, address(this), collateralAmount);
        emit CollateralDeposited(msg.sender, token, collateralAmount);
    }

    // function mintNgns(address token, uint128 ngnsAmount) external {
    //     _checkDepositReq(token, uint256(ngnsAmount));
    //     _storeCollateralPosition(token, collateralAmount, 1);
    //     IERC20(token).safeTransferFrom(msg.sender, address(this), collateralAmount);
    //     emit CollateralDeposited(msg.sender, token, collateralAmount);
    // }
}
