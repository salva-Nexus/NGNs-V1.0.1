// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title NGNOracle
/// @notice Standalone (non-proxy) oracle providing NGN price data scaled to 6 decimals.
contract NGNOracle is AccessControl {
    bytes32 public constant PRICE_UPDATE_ROLE = keccak256("PRICE_UPDATE_ROLE");

    /// @notice Oracle answer precision (6 decimals)
    uint8 public constant decimals = 6;

    struct PriceConfig {
        uint256 pricePerUsd;
        uint256 updatedAt;
    }

    PriceConfig internal priceConfig;

    // --- Custom Errors ---
    error NGNOracle__InvalidPrice();

    // --- Events ---
    event PriceUpdated(uint256 indexed newPrice, uint256 indexed timestamp);

    /// @notice Deploys the oracle and sets initial roles and price directly
    /// @param initialPrice Scaled price value (e.g., 840 for 0.00084 USD at 6 decimals)
    constructor(uint256 initialPrice) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRICE_UPDATE_ROLE, msg.sender);

        _updatePrice(initialPrice);
    }

    /// @notice Updates the stored price
    /// @param newPrice Scaled price value in 6 decimals
    function updatePrice(uint256 newPrice) external onlyRole(PRICE_UPDATE_ROLE) returns (bool) {
        _updatePrice(newPrice);
        return true;
    }

    /// @notice Internal helper for setting price state
    function _updatePrice(uint256 newPrice) internal {
        if (newPrice == 0) revert NGNOracle__InvalidPrice();

        priceConfig = PriceConfig({ pricePerUsd: newPrice, updatedAt: block.timestamp });

        emit PriceUpdated(newPrice, block.timestamp);
    }

    // --- View Methods ---

    /// @notice Returns current NGN price configuration
    function getNgnPricePerUsd() external view returns (PriceConfig memory) {
        return priceConfig;
    }
}
