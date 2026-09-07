// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Errors } from "../utils/Errors.sol";
import { Storage } from "../utils/Storage.sol";
import { INGNOracle } from "@INGNOracle/INGNOracle.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/AggregatorV3Interface.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
        address pFeed = allowedCollateralFeeds[token];
        // GET PRICE OF 1 COLLATERAL IN USD - eg 1WETH = $2000 => 200000000000
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = priceFeed(pFeed);
        // GET PRICE OF 1 NGN IN USD - eg 1NGN = 0.00084 USD => 840
        (uint256 usdPricePerNgn, uint256 updatedAtForNgn) = INGNOracle(ngnPriceFeed).getUsdPricePerNgn();
        // STALENESS CHECK
        _stalenessCheckChainlink(updatedAt, roundId, answeredInRound);
        _stalenessCheckNgn(updatedAtForNgn);
        // GET NGN ORACLE DECIMALS => 6
        uint8 ngnOracleDecimals = INGNOracle(ngnPriceFeed).decimals();
        // TO GET WHAT 1 USD IS IN NGN
        uint256 ngnPricePerUsd = (10 ** ngnOracleDecimals * 10 ** ngnOracleDecimals) / usdPricePerNgn;
        // TO GET THE USD PRICE OF THE INPUTTED COLLATERAL AMOUNT
        uint256 collaterAmountToUsd = collateralAmount * uint256(price);
        // NOW DERIVE THE NGN VALUE OF THE COLLATERAL USD VALUE
        uint256 collaterAmountToNgn =
            (collaterAmountToUsd * ngnPricePerUsd) / (10 ** _feedDecimalOf(pFeed) * 10 ** ngnOracleDecimals);
        // NOW GET THE ABSOLUTE VALUE SCALED TO THE DECIMALS OF NGNS CONTRACT
        nValue = (collaterAmountToNgn * 10 ** _decimalOf(ngns)) / 10 ** _decimalOf(token);
    }

    function collateralValue(address token, uint256 ngnsAmount) public view returns (uint256 cValue, uint256 liqBonus) {
        address pFeed = allowedCollateralFeeds[token];
        // GET PRICE OF 1 COLLATERAL IN USD - eg 1WETH = $2000 => 200000000000
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = priceFeed(pFeed);
        // GET PRICE OF 1 NGN IN USD - eg 1NGN = 0.00084 USD => 840
        (uint256 usdPricePerNgn, uint256 updatedAtForNgn) = INGNOracle(ngnPriceFeed).getUsdPricePerNgn();
        // STALENESS CHECK
        _stalenessCheckChainlink(updatedAt, roundId, answeredInRound);
        _stalenessCheckNgn(updatedAtForNgn);
        // GET NGN ORACLE DECIMALS => 6
        uint8 ngnOracleDecimals = INGNOracle(ngnPriceFeed).decimals();
        // TO GET WHAT 1 USD IS IN NGN
        uint256 ngnPricePerUsd = (10 ** ngnOracleDecimals * 10 ** ngnOracleDecimals) / usdPricePerNgn;

        // TO GET THE USD VALUE OF THE AMOUNT
        // Beacuse we will divide by chainlinks usd price which is 8 decimals after this, we need to scale amount to 8
        // decimal 5000 / 1190.476190 = 4.2 => (5000e6 * 1e8) /  1190476190 = 420000000
        // Scale amount to 1e18 also, to avoid rounding to 0 on values like 1 NGN
        uint256 usdValueOfNgnsAmount = (ngnsAmount * 10 ** _feedDecimalOf(pFeed) * DECIMAL_SCALER) / ngnPricePerUsd;

        // TO GET THE COLLATERAL VALUE OF THE USD AMOUNT
        // now we scale the usdValueOfNgnsAmount to 18 decimals to finally match the weth decimals before dividing
        // 4.2/2000 = 0.002 => (420000000 * 1e18) / 2000e8 = 2100000000000000 = 0.0021
        uint256 tokenDecimals = _decimalOf(token);
        uint256 tokenScale = 10 ** tokenDecimals;
        cValue = ((usdValueOfNgnsAmount * tokenScale) / uint256(price)) / DECIMAL_SCALER;
        liqBonus = (cValue * LIQ_BONUS) / PERCENTAGE_SCALER;
    }

    function _stalenessCheckNgn(uint256 lastUpdated) internal view {
        if (block.timestamp - lastUpdated > STALE_PRICE_THRESHOLD) {
            revert PM__StalePrice();
        }
    }

    function _stalenessCheckChainlink(uint256 lastUpdated, uint80 roundId, uint80 answeredInRound) internal view {
        if (block.timestamp - lastUpdated > STALE_PRICE_THRESHOLD) {
            revert PM__StalePrice();
        }
        if (answeredInRound < roundId) {
            revert PM__StalePrice();
        }
        if (roundId == 0) {
            revert PM__InvalidRound();
        }
    }

    function _decimalOf(address token) internal view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }

    function _feedDecimalOf(address pFeed) internal view returns (uint8) {
        return AggregatorV3Interface(pFeed).decimals();
    }
}
