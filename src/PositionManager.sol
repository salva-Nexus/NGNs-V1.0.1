// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IAdapter } from "./interfaces/IAdapter.sol";
import { Checkers } from "./utils/Checkers.sol";
import { Events } from "./utils/Events.sol";
import { Modifier } from "./utils/Modifier.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
    function registerCollateral(address token, uint48 ratio, uint48 liqThreshold) external {
        address priceFeedAddress = allowedCollateralFeeds[token];
        if (priceFeedAddress == address(0)) revert PM__TokenNotWhitelisted();

        (, int256 price,,,) = priceFeed(priceFeedAddress);
        _checkCollateralReq(token, uint256(price), uint256(ratio), uint256(liqThreshold));
        _storeCollateralConfig(token, priceFeedAddress, ratio, liqThreshold);

        emit CollateralRegistered(msg.sender, token, priceFeedAddress);
    }

    function depositCollateral(address token, uint128 collateralAmount) external {
        _checkDepositAndMintReq(token, uint256(collateralAmount));
        _updateCollateralValue(token, uint128(collateralAmount), 1);
        IERC20(token).safeTransferFrom(msg.sender, address(this), uint256(collateralAmount));
        emit CollateralDeposited(msg.sender, token, uint256(collateralAmount));
    }

    function mintNgns(address token, uint128 ngnsAmount) external nonReentrant {
        _checkDepositAndMintReq(token, uint256(ngnsAmount));
        (CollateralConfig memory config, PositionConfig memory positions) = userConfig(msg.sender, token);
        uint256 ngnValue = getNgnValue(token, uint256(positions.collateralDeposited));
        _validatePositionHealth(config, positions, ngnValue, uint256(ngnsAmount));
        _updateDebtValue(token, ngnsAmount, 1);
        IAdapter(adapter).supply(msg.sender, uint256(ngnsAmount));
        emit NgnsMinted(msg.sender, token, uint256(ngnsAmount));
    }
}
