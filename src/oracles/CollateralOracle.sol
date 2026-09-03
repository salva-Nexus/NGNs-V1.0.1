// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AggregatorV3Interface } from "@chainlink/contracts/AggregatorV3Interface.sol";

abstract contract CollateralOracle {
    function priceFeed(address pFeed)
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        AggregatorV3Interface dataFeed = AggregatorV3Interface(pFeed);
        return dataFeed.latestRoundData();
    }
}
