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

    function getNgnValue(address token, uint256 collateralAmount) public view returns (uint256 ngnValue) {
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
        uint256 collaterAmountToNgn = (collaterAmountToUsd * ngnPricePerUsd)
            / (10 ** AggregatorV3Interface(pFeed).decimals() * 10 ** ngnOracleDecimals);
        // NOW GET THE ABSOLUTE VALUE SCALED TO THE DECIMALS OF NGNS CONTRACT
        uint8 ngnsDecimals = IERC20Metadata(ngns).decimals();
        uint8 collateralDecimals = IERC20Metadata(token).decimals();
        ngnValue = (collaterAmountToNgn * 10 ** ngnsDecimals) / 10 ** collateralDecimals;
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
}
