// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Errors } from "../utils/Errors.sol";
import { Storage } from "../utils/Storage.sol";
import { INGNOracle } from "@INGNOracle/INGNOracle.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/AggregatorV3Interface.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { console } from "forge-std/console.sol";

abstract contract CollateralOracle is Storage, Errors {
    function priceFeed(address pFeed)
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        AggregatorV3Interface dataFeed = AggregatorV3Interface(pFeed);
        return dataFeed.latestRoundData();
    }

    function ngnValue(address token, uint256 collateralAmount) public view returns (uint256 nValue) {
        // GET PRICE OF 1 COLLATERAL IN USD - eg 1WETH = $2000 => 200000000000
        int256 price = _stalenessCheckChainlink(token);
        uint256 usdPricePerNgn = _stalenessCheckNgn();
        // GET NGN ORACLE DECIMALS => 6
        uint8 ngnOracleDecimals = INGNOracle(ngnPriceFeed).decimals();
        uint8 ngnsDec = _decimalOf(ngns);
        // TO GET WHAT 1 USD IS IN NGN
        uint256 ngnPricePerUsd =
            (10 ** ngnsDec * DECIMAL_SCALER) / ((usdPricePerNgn * 10 ** ngnsDec) / 10 ** ngnOracleDecimals);
        // TO GET THE USD PRICE OF THE INPUTTED COLLATERAL AMOUNT
        uint256 collaterAmountToUsd = (collateralAmount * uint256(price) * DECIMAL_SCALER)
            / (CHAINLINK_ANSWER_DECIMALS * 10 ** _decimalOf(token));
        // NOW DERIVE THE NGN VALUE OF THE COLLATERAL USD VALUE
        uint256 collaterAmountToNgn = (collaterAmountToUsd * ngnPricePerUsd) / DECIMAL_SCALER;
        // NOW GET THE ABSOLUTE VALUE SCALED TO THE DECIMALS OF NGNS CONTRACT
        nValue = (collaterAmountToNgn * 10 ** ngnsDec) / DECIMAL_SCALER;
    }

    function collateralValue(address token, uint256 ngnsAmount) public view returns (uint256 cValue, uint256 liqBonus) {
        // GET PRICE OF 1 NGN IN USD - eg 1NGN = 0.00084 USD => 840
        int256 price = _stalenessCheckChainlink(token);
        uint256 usdPricePerNgn = _stalenessCheckNgn();
        // GET NGN ORACLE DECIMALS => 6
        uint8 ngnOracleDecimals = INGNOracle(ngnPriceFeed).decimals();
        // TO GET WHAT 1 USD IS IN NGN
        uint8 ngnsDec = _decimalOf(ngns);
        uint256 ngnPricePerUsd =
            (10 ** ngnsDec * DECIMAL_SCALER) / ((usdPricePerNgn * 10 ** ngnsDec) / 10 ** ngnOracleDecimals);
        // TO GET THE USD VALUE OF THE AMOUNT
        uint256 usdValueOfNgnsAmount = (ngnsAmount * DECIMAL_SCALER * (DECIMAL_SCALER / 10 ** ngnsDec)) / ngnPricePerUsd;
        uint256 tokenScale = 10 ** ngnsDec;
        uint256 priceToTokenScale = (uint256(price) * DECIMAL_SCALER) / CHAINLINK_ANSWER_DECIMALS;
        cValue = (usdValueOfNgnsAmount * tokenScale) / priceToTokenScale;
        liqBonus = (cValue * LIQ_BONUS) / PERCENTAGE_SCALER;
    }

    function _stalenessCheckNgn() internal view returns (uint256) {
        (uint256 usdPricePerNgn, uint256 updatedAtForNgn) = INGNOracle(ngnPriceFeed).getUsdPricePerNgn();
        if (block.timestamp - updatedAtForNgn > STALE_PRICE_THRESHOLD) {
            revert PM__StalePrice();
        }
        if (usdPricePerNgn <= 0) revert PM__InvalidPrice();
        return usdPricePerNgn;
    }

    function _stalenessCheckChainlink(address token) internal view returns (int256) {
        address pFeed = allowedCollateralFeeds[token];
        // GET PRICE OF 1 COLLATERAL IN USD - eg 1WETH = $2000 => 200000000000
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = priceFeed(pFeed);
        if (block.timestamp - updatedAt > STALE_PRICE_THRESHOLD) {
            revert PM__StalePrice();
        }
        if (answeredInRound < roundId) {
            revert PM__StalePrice();
        }
        if (roundId == 0) {
            revert PM__InvalidRound();
        }
        if (uint256(price) <= 0) revert PM__InvalidPrice();
        return price;
    }

    function _decimalOf(address token) internal view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }
}
