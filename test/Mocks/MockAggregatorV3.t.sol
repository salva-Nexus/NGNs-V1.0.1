// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title MockAggregatorV3
/// @notice Minimal Chainlink price feed mock for testing
contract MockAggregatorV3 {
    uint8 public decimals;
    int256 private s_price;
    uint80 private s_roundId;
    uint256 private s_updatedAt;

    constructor(uint8 _decimals, int256 _initialPrice) {
        decimals = _decimals;
        updateAnswer(_initialPrice);
    }

    /// @notice Helper function to update mock price in unit tests
    function updateAnswer(int256 _newPrice) public {
        s_price = _newPrice;
        s_roundId++;
        s_updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (s_roundId, s_price, s_updatedAt, s_updatedAt, s_roundId);
    }
}
