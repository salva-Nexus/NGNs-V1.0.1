// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title INGNOracle
/// @notice Interface for the NGNOracle contract
interface INGNOracle {
    struct PriceConfig {
        uint256 pricePerUsd;
        uint256 updatedAt;
    }
    function getNgnPricePerUsd() external view returns (PriceConfig memory, uint8);
}
