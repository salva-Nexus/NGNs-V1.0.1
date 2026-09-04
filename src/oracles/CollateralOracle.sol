// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Checkers } from "../utils/Checkers.sol";
import { INGNOracle } from "@INGNOracle/INGNOracle.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/AggregatorV3Interface.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

abstract contract CollateralOracle is Checkers {
    function priceFeed(address pFeed)
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        AggregatorV3Interface dataFeed = AggregatorV3Interface(pFeed);
        return dataFeed.latestRoundData();
    }

    function getNgnValue(address token, address pFeed, uint256 collateralAmount)
        public
        view
        returns (uint256 ngnValue)
    {
        // GET PRICE OF 1 COLLATERAL IN USD - eg 1WETH = $2000 => 200000000000
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = priceFeed(pFeed);
        // GET PRICE OF 1 NGN IN USD - eg 1NGN = 0.00084 USD => 840
        (uint256 usdPricePerNgn, uint256 updatedAtForNgn) = INGNOracle(ngnPriceFeed).getUsdPricePerNgn();
        // STALENESS CHECK
        _stalenessCheckChainlink(updatedAt, roundId, answeredInRound);
        _stalenessCheckNgn(updatedAtForNgn);
        // GET NGN ORACLE DECIMALS => 6
        uint8 ngnOracleDecimals = INGNOracle(ngnPriceFeed).decimals();
        // TO GET WHAT 1 USD IS IN NGN => 1/USDPRICEPERNGN = 1 / 0.00084 = 1e6 / USDPRICEPERNGN = 1190476190 =>
        // 1190.476190
        uint256 ngnPricePerUsd = (10 ** ngnOracleDecimals * 10 ** ngnOracleDecimals) / usdPricePerNgn;
        // TO GET THE USD PRICE OF THE INPUTTED COLLATERAL AMOUNT - amount * usdPrice = 100 WETH * 2000 USD = 200,000
        // 100e18 * 200000000000 = 200000 00000000000000000000000000
        uint256 collaterAmountToUsd = collateralAmount * uint256(price);
        // NOW DERIVE THE NGN VALUE OF THE COLLATERAL USD VALUE
        // (20000000000000000000000000000000 * 1190476190) / (1e8 * 1e6) = 238095238000000000000000000 (238,095,238)
        uint256 collaterAmountToNgn = (collaterAmountToUsd * ngnPricePerUsd)
            / (10 ** AggregatorV3Interface(pFeed).decimals() * 10 ** ngnOracleDecimals);
        // NOW GET THE ABSOLUTELY VALUE SCALED TO THE DECIMALS OF NGNS CONTRACT
        // (238095238000000000000000000 * 1e6) / 1e18 = 238095238000000 = 238,095,238 NGN = 1 WETH
        uint8 ngnsDecimals = IERC20Metadata(ngns).decimals();
        uint8 collateralDecimals = IERC20Metadata(token).decimals();
        ngnValue = (collaterAmountToNgn * 10 ** ngnsDecimals) / 10 ** collateralDecimals;
    }
}
