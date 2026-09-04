// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title NGNOracle
/// @notice Upgradeable UUPS oracle providing NGN price data scaled to 6 decimals.
contract NGNOracle is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant PRICE_UPDATE_ROLE = keccak256("PRICE_UPDATE_ROLE");

    /// @notice Oracle answer precision (6 decimals)
    uint8 public constant decimals = 6;

    struct PriceConfig {
        uint256 pricePerNgn;
        uint256 updatedAt;
    }

    PriceConfig internal priceConfig;

    // --- Custom Errors ---
    error NGNOracle__InvalidPrice();

    // --- Events ---
    event PriceUpdated(uint256 indexed newPrice, uint256 indexed timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the upgradeable contract state
    /// @param initialPrice Scaled price value (e.g., 840 for 0.00084 USD at 6 decimals)
    function initialize(uint256 initialPrice) external initializer {
        __AccessControl_init();

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

        priceConfig = PriceConfig({ pricePerNgn: newPrice, updatedAt: block.timestamp });

        emit PriceUpdated(newPrice, block.timestamp);
    }

    // --- View Methods ---

    /// @notice Returns current NGN price configuration
    function getUsdPricePerNgn() external view returns (uint256 price, uint256 updatedAt) {
        return (priceConfig.pricePerNgn, priceConfig.updatedAt);
    }

    /// @dev Restricts upgrade authorization strictly to the DEFAULT_ADMIN_ROLE
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
