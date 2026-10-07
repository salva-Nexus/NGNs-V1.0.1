// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IAdapter } from "./interfaces/IAdapter.sol";
import { Checkers } from "./utils/Checkers.sol";
import { Events } from "./utils/Events.sol";
import { Modifier } from "./utils/Modifier.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title PositionManager
/// @author cboi@salva
/// @notice Core vault management contract handling collateral deposits, debt minting, settlement, withdrawals, and
/// liquidations.
/// @dev Implements Checkers, Events, and Modifier helper utilities to maintain isolated position safety.
contract PositionManager is Checkers, Events, Modifier {
    using SafeERC20 for IERC20;

    constructor(
        address _ngns,
        address _ngnPriceFeed,
        address _adapter,
        address[] memory token,
        address[] memory priceFeedAddress,
        uint256 _maxCap
    ) {
        ngns = _ngns;
        ngnPriceFeed = _ngnPriceFeed;
        adapter = _adapter;
        MINT_CAP = _maxCap;

        if (token.length != priceFeedAddress.length) revert PM__InvalidTokenToFeedLength();
        _whitelistCollateralToken(token, priceFeedAddress);
    }

    /* ========================================================================================= */
    /*                                      ADMIN & REGISTRATION                                 */
    /* ========================================================================================= */

    function _whitelistCollateralToken(address[] memory token, address[] memory priceFeedAddress) internal {
        for (uint256 i = 0; i < token.length;) {
            if (token[i] == address(0) && priceFeedAddress[i] == address(0)) revert PM__InvalidPriceFeed();

            allowedCollateralFeeds[token[i]] = priceFeedAddress[i];
            emit CollateralWhitelisted(token[i], priceFeedAddress[i]);

            unchecked {
                i++;
            }
        }
    }

    function registerCollateral(address token, uint96 ratio) public {
        address priceFeedAddress = allowedCollateralFeeds[token];
        if (priceFeedAddress == address(0)) revert PM__TokenNotWhitelisted();

        (, int256 price,,,) = priceFeed(priceFeedAddress);
        _checkCollateralReq(token, uint256(price), uint256(ratio));
        _storeCollateralConfig(msg.sender, token, priceFeedAddress, ratio);
        emit CollateralRegistered(msg.sender, token, priceFeedAddress);
    }

    function updateCollateralConfig(address token, uint96 newRatio) external {
        PositionConfig memory positions = positionConfig(msg.sender, token);
        bool verified = _checkUpdateReq(token, newRatio, positions.mintedNgns > 0);
        if (!verified) {
            registerCollateral(token, newRatio);
            return;
        }
        _updateCollateralConfig(msg.sender, token, newRatio);
        emit CollateralConfigUpdated(msg.sender, token, uint256(newRatio));
    }

    /* ========================================================================================= */
    /*                                       CORE POSITION LOGIC                                 */
    /* ========================================================================================= */

    function depositCollateral(address token, uint128 collateralAmount) public payable {
        if (collateralAmount > 0 && msg.value > 0) revert PM__Amount_Mismatch();
        if (token == address(0) && collateralAmount > 0) revert PM__Amount_Mismatch();
        uint128 cacheAmount = collateralAmount == 0 ? uint128(msg.value) : collateralAmount;
        _checkDepositAndMintReq(token, uint256(cacheAmount), address(0));
        _updateCollateralValue(msg.sender, token, cacheAmount, 1);
        emit CollateralDeposited(msg.sender, token, uint256(cacheAmount));
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), uint256(cacheAmount));
        }
    }

    function openPosition(address token, uint128 ngnsAmount) public {
        (CollateralConfig memory config, PositionConfig memory positions) = userConfig(msg.sender, token);
        _checkDepositAndMintReq(token, uint256(ngnsAmount), config.priceFeed);
        uint256 nValue = ngnValue(token, uint256(positions.collateralDeposited));
        _validatePositionHealth(
            nValue, uint256(ngnsAmount), uint256(positions.mintedNgns), uint256(config.customCollateralRatio)
        );
        _updateDebtValue(msg.sender, token, ngnsAmount, 1);
        emit PositionOpened(msg.sender, token, uint256(ngnsAmount));
        IAdapter(adapter).supply(msg.sender, uint256(ngnsAmount));
    }

    function settlePosition(address token, uint128 ngnsAmount) public {
        _updateDebtValue(msg.sender, token, ngnsAmount, 0);
        IAdapter(adapter).repay(msg.sender, ngnsAmount);
        emit DebtSettled(msg.sender, token, ngnsAmount);
    }

    function withdraw(address token, address receiver, uint128 amount) public {
        (CollateralConfig memory config, PositionConfig memory positions) = userConfig(msg.sender, token);
        _checkWithdrawalReq(
            token,
            receiver,
            uint256(positions.collateralDeposited),
            uint256(positions.mintedNgns),
            uint256(config.customCollateralRatio)
        );
        _updateCollateralValue(msg.sender, token, amount, 0);
        _checkFinalWithdrawalReq(token, uint256(config.customCollateralRatio));
        emit CollateralWithdrawn(msg.sender, token, receiver, amount);
        IERC20(token).safeTransfer(receiver, uint256(amount));
    }

    /* ========================================================================================= */
    /*                                      LIQUIDATION & PURGING                                */
    /* ========================================================================================= */

    function purge(address user, address token, address receiver, uint128 ngnsAmount) external {
        PositionConfig memory positions = positionConfig(user, token);
        uint256 amountToBurn = _checkPurgeReq(user, receiver, token, uint256(ngnsAmount), uint256(positions.mintedNgns));
        (uint256 cValue, uint256 liqBonus) = collateralValue(token, amountToBurn);
        if (cValue == 0) revert PM__AmountTooSmall();

        uint256 totalSeized = cValue + liqBonus;
        if (totalSeized > positions.collateralDeposited) {
            totalSeized = positions.collateralDeposited;
        }

        _updateDebtValue(user, token, uint128(amountToBurn), 0);
        _updateCollateralValue(user, token, uint128(totalSeized), 0);

        emit Purged(user, token, msg.sender, receiver, amountToBurn, totalSeized, liqBonus);
        IAdapter(adapter).repay(msg.sender, uint256(amountToBurn));
        if (token == address(0)) {
            (bool success,) = payable(receiver).call{ value: totalSeized }("");
            if (!success) revert PM__ETHTransferFailed();
            return;
        }
        IERC20(token).safeTransfer(receiver, totalSeized);
    }

    /* ========================================================================================= */
    /*                                      ATOMIC COMPOUND ACTIONS                              */
    /* ========================================================================================= */

    function depositAndOpenPosition(address token, uint128 cAmount, uint128 nAmount) external {
        depositCollateral(token, cAmount);
        openPosition(token, nAmount);
    }

    function settleAndWithdraw(address token, address receiver, uint128 nAmountToBurn, uint128 cAmountToWithdraw)
        external
    {
        settlePosition(token, nAmountToBurn);
        withdraw(token, receiver, cAmountToWithdraw);
    }
}
