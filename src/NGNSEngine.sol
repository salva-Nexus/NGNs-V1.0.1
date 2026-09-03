// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Checkers } from "./utils/Checkers.sol";
import { Events } from "./utils/Events.sol";
import { INGNOracle } from "@INGNOracle/INGNOracle.sol";
import { INGNS } from "@INGNS/INGNS.sol";
import { CollateralOracle } from "@Oracles/CollateralOracle.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NGNSEngine is Checkers, Events, CollateralOracle, Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address ngnsTokenAddress, address priceFeedAddress) external initializer {
        __AccessControl_init();

        ngnsToken = ngnsTokenAddress;
        ngnPriceFeed = priceFeedAddress;
    }

    /// @notice Permissionless Collateral Registration via Chainlink Feed Check
    function registerCollateral(address token, address priceFeedAddress, uint80 minRatio) external {
        CollateralConfig storage config = collateralConfigs[token];
        _ensureNotLive(config, true);
        // Validate Oracle Feed
        (, int256 price,,,) = priceFeed(priceFeedAddress);
        if (price <= 0) revert NGNSEngine__InvalidOracle();

        if (minRatio < MIN_COLLATERAL_RATIO) {
            revert NGNSEngine__InvalidCollateralRatio();
        }

        config.priceFeed = priceFeedAddress;
        config.isSupported = 1;
        config.collateralRatio = minRatio;
        emit CollateralRegistered(token, priceFeedAddress);
    }

    function unregisterCollateral(address token) external {
        CollateralConfig storage config = collateralConfigs[token];
        _ensureNotLive(config, false);
        config.isSupported = 0;
        emit CollateralUnregistered(token, config.priceFeed);
    }

    function depositCollateral(address token, uint128 collateralAmount) external {
        CollateralConfig storage config = collateralConfigs[token];
        if (config.isSupported == 0) {
            revert NGNSEngine__UnsupportedCollateral();
        }
        _storePositions(msg.sender, token, collateralAmount, 0);
        IERC20(token).safeTransferFrom(msg.sender, address(this), collateralAmount);
        emit CollateralDeposited(msg.sender, token, collateralAmount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
