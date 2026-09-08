// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IAdapter } from "./interfaces/IAdapter.sol";
import { Checkers } from "./utils/Checkers.sol";
import { Events } from "./utils/Events.sol";
import { Modifier } from "./utils/Modifier.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { console } from "forge-std/console.sol";

contract PositionManager is Checkers, Events, Modifier {
    using SafeERC20 for IERC20;

    constructor(
        address _ngns,
        address _ngnPriceFeed,
        address _adapter,
        address[] memory token,
        address[] memory priceFeedAddress
    ) {
        ngns = _ngns;
        ngnPriceFeed = _ngnPriceFeed;
        adapter = _adapter;

        if (token.length != priceFeedAddress.length) revert PM__InvalidTokenToFeedLength();
        _whitelistCollateralToken(token, priceFeedAddress);
    }

    /// @notice Admin whitelists an approved token and its verified Chainlink USD feed
    function _whitelistCollateralToken(address[] memory token, address[] memory priceFeedAddress) internal {
        for (uint256 i = 0; i < token.length;) {
            if (token[i] == address(0) || priceFeedAddress[i] == address(0)) revert PM__InvalidPriceFeed();

            allowedCollateralFeeds[token[i]] = priceFeedAddress[i];
            emit CollateralWhitelisted(token[i], priceFeedAddress[i]);

            unchecked {
                i++;
            }
        }
    }

    /// @notice User permissionlessly registers their isolated position using a whitelisted token
    function registerCollateral(address token, uint48 ratio, uint48 liqThreshold) public {
        address priceFeedAddress = allowedCollateralFeeds[token];
        if (priceFeedAddress == address(0)) revert PM__TokenNotWhitelisted();

        (, int256 price,,,) = priceFeed(priceFeedAddress);
        _checkCollateralReq(token, uint256(price), uint256(ratio), uint256(liqThreshold));
        _storeCollateralConfig(msg.sender, token, priceFeedAddress, ratio, liqThreshold);

        emit CollateralRegistered(msg.sender, token, priceFeedAddress);
    }

    function depositCollateral(address token, uint128 collateralAmount) external {
        _checkDepositAndMintReq(token, uint256(collateralAmount), address(0));
        _updateCollateralValue(msg.sender, token, uint128(collateralAmount), 1);
        IERC20(token).safeTransferFrom(msg.sender, address(this), uint256(collateralAmount));
        emit CollateralDeposited(msg.sender, token, uint256(collateralAmount));
    }

    function openPosition(address token, uint128 ngnsAmount) external nonReentrant {
        (CollateralConfig memory config, PositionConfig memory positions) = userConfig(msg.sender, token);
        _checkDepositAndMintReq(token, uint256(ngnsAmount), config.priceFeed);
        uint256 nValue = ngnValue(token, uint256(positions.collateralDeposited));
        _validatePositionHealth(config, positions, token, nValue, uint256(ngnsAmount));
        _updateDebtValue(msg.sender, token, ngnsAmount, 1);
        IAdapter(adapter).supply(msg.sender, uint256(ngnsAmount));
        emit PositionOpened(msg.sender, token, uint256(ngnsAmount));
    }

    function settlePosition(address token, uint128 ngnsAmount) external {
        _updateDebtValue(msg.sender, token, ngnsAmount, 0);
        IAdapter(adapter).repay(msg.sender, ngnsAmount);
        emit DebtSettled(msg.sender, token, ngnsAmount);
    }

    function purge(address user, address token, address receiver, uint128 ngnsAmount) external {
        _checkPurgeReq(user, receiver, token, ngnsAmount);
        (uint256 cValue, uint256 liqBonus) = collateralValue(token, ngnsAmount);
        require(cValue > 0, "Amount too small");
        // Fetch position
        (, PositionConfig memory positions) = userConfig(user, token);
        uint256 totalSeized = cValue + liqBonus;
        if (totalSeized > positions.collateralDeposited) {
            totalSeized = positions.collateralDeposited;
        }
        IAdapter(adapter).repay(msg.sender, uint256(ngnsAmount));
        _updateDebtValue(user, token, ngnsAmount, 0);
        _updateCollateralValue(user, token, uint128(totalSeized), 0);
        IERC20(token).safeTransfer(receiver, totalSeized);
        emit Purged(user, token, msg.sender, receiver, ngnsAmount, totalSeized, liqBonus);
    }

    function updateCollateralConfig(address token, uint48 newRatio, uint48 newLiqThreshold) external {
        (CollateralConfig memory config, PositionConfig memory positions) = userConfig(msg.sender, token);
        bool verified = _checkUpdateReq(
            token,
            uint256(newRatio),
            uint256(newLiqThreshold),
            uint256(config.customCollateralRatio),
            positions.mintedNgns > 0
        );
        if (!verified) {
            registerCollateral(token, newRatio, newLiqThreshold);
            return;
        }
        _updateCollateralConfig(msg.sender, token, newRatio, newLiqThreshold);
        emit CollateralConfigUpdated(msg.sender, token, newRatio, newLiqThreshold);
    }
}
