// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Checkers } from "./utils/Checkers.sol";
import { Events } from "./utils/Events.sol";
import { Modifier } from "./utils/Modifier.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract NGNSEngine is Checkers, Events, Modifier, AccessControl {
    using SafeERC20 for IERC20;

    /// @notice Admin whitelists an approved token and its verified Chainlink USD feed
    function whitelistCollateralToken(address token, address priceFeedAddress)
        external
        onlyRole(COLLATERAL_MANAGER_ROLE)
    {
        if (priceFeedAddress == address(0)) revert NGNS__InvalidPriceFeed();

        allowedCollateralFeeds[token] = priceFeedAddress;
        emit CollateralWhitelisted(token, priceFeedAddress);
    }

    /// @notice User permissionlessly registers their isolated position using a whitelisted token
    function registerCollateral(address token, uint48 ratio, uint48 liqThreshold) external {
        address priceFeedAddress = allowedCollateralFeeds[token];
        if (priceFeedAddress == address(0)) revert NGNS__TokenNotWhitelisted();

        (, int256 price,,,) = priceFeed(priceFeedAddress);
        _checkCollateralReq(token, uint256(price), uint256(ratio), uint256(liqThreshold));
        _storeCollateralConfig(token, priceFeedAddress, ratio, liqThreshold);

        emit CollateralRegistered(msg.sender, token, priceFeedAddress);
    }

    function depositCollateral(address token, uint128 collateralAmount) external {
        _checkDepositAndMintReq(token, uint256(collateralAmount));
        _updateCollateralValue(token, uint128(collateralAmount), 1);
        IERC20(token).safeTransferFrom(msg.sender, address(this), collateralAmount);
        emit CollateralDeposited(msg.sender, token, collateralAmount);
    }

    function mintNgns(address token, uint128 ngnsAmount) external nonReentrant {
        _checkDepositAndMintReq(token, uint256(ngnsAmount));
        (CollateralConfig memory config, PositionConfig memory positions) = userConfig(msg.sender, token);
        uint256 ngnValue = getNgnValue(token, uint256(positions.collateralDeposited));
        _validatePositionHealth(config, positions, ngnValue, uint256(ngnsAmount));
        _updateDebtValue(token, ngnsAmount, 1);

        _mintNgns(msg.sender, uint256(ngnsAmount));

        emit NgnsMinted(msg.sender, token, ngnsAmount);
    }

    function _mintNgns(address account, uint256 value) internal virtual;
}

/// @title NGNS Token & Engine Unified Contract
/// @author Salva
/// @notice Combined Decentralized Nigerian Naira (NGNS) Stablecoin & Engine
contract NGNS is ERC20, NGNSEngine {
    constructor(address _ngnPriceFeed) ERC20("Nigerian Naira Salva", "NGNS") {
        ngnPriceFeed = _ngnPriceFeed;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COLLATERAL_MANAGER_ROLE, msg.sender);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // Implements engine hook using OZ ERC20's non-virtual _mint
    function _mintNgns(address account, uint256 value) internal override {
        _mint(account, value);
    }
}
