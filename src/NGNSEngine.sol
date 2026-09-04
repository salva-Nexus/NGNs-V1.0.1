// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Checkers } from "./utils/Checkers.sol";
import { Events } from "./utils/Events.sol";
import { INGNOracle } from "@INGNOracle/INGNOracle.sol";
import { INGNS } from "@INGNS/INGNS.sol";
import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NGNSEngine is Checkers, Events, Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address ngnsTokenAddress, address priceFeedAddress) external initializer {
        __AccessControl_init();

        ngns = ngnsTokenAddress;
        ngnPriceFeed = priceFeedAddress;
    }

    /// @notice Permissionless Collateral Registration via Chainlink Feed Check
    function registerCollateral(
        address token,
        address priceFeedAddress,
        uint48 ratio,
        uint48 liqThreshold
    ) external {
        _checkCollateralReq(token, priceFeedAddress, uint256(ratio), uint256(liqThreshold));
        _storeCollateralConfig(token, priceFeedAddress, ratio, liqThreshold);
        emit CollateralRegistered(msg.sender, token, priceFeedAddress);
    }

    function depositCollateral(address token, uint128 collateralAmount) external {
        _checkDepositReq(token, uint256(collateralAmount));
        _storeCollateralPosition(token, collateralAmount, 1);
        IERC20(token).safeTransferFrom(msg.sender, address(this), collateralAmount);
        emit CollateralDeposited(msg.sender, token, collateralAmount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    { }
}
