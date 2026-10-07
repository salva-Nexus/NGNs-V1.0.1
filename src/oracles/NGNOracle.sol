// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AggregatorV3Interface } from "@chainlink/contracts/AggregatorV3Interface.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NGNOracle is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant PRICE_UPDATE_ROLE = keccak256("PRICE_UPDATE_ROLE");
    uint8 public constant decimals = 18;

    struct PriceConfig {
        uint256 pricePerNgn;
        uint256 updatedAt;
    }
    PriceConfig internal priceConfig;

    // Mapping from token address to its Chainlink USD price feed
    mapping(address => address) public tokenToUsdFeed;

    // --- Custom Errors ---
    error NGNOracle__InvalidPrice();
    error NGNOracle__InvalidAddress();

    // --- Events ---
    event PriceUpdated(uint256 indexed newPrice, uint256 indexed timestamp);
    event TokenFeedUpdated(address indexed token, address indexed feed);

    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 initialPrice) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRICE_UPDATE_ROLE, msg.sender);
        _updatePrice(initialPrice);
    }

    function updatePrice(uint256 newPrice) external onlyRole(PRICE_UPDATE_ROLE) returns (bool) {
        _updatePrice(newPrice);
        return true;
    }

    function setTokenUsdFeed(address token, address feed) external onlyRole(PRICE_UPDATE_ROLE) {
        if (feed == address(0)) revert NGNOracle__InvalidAddress();
        tokenToUsdFeed[token] = feed;
        emit TokenFeedUpdated(token, feed);
    }

    function _updatePrice(uint256 newPrice) internal {
        if (newPrice == 0) revert NGNOracle__InvalidPrice();
        priceConfig = PriceConfig({ pricePerNgn: newPrice, updatedAt: block.timestamp });
        emit PriceUpdated(newPrice, block.timestamp);
    }

    function getUsdPricePerNgn() external view returns (uint256 price, uint256 updatedAt) {
        return (priceConfig.pricePerNgn, priceConfig.updatedAt);
    }

    function getAssetPricePerNgn(address asset) external view returns (uint256 price, uint256 updatedAt) {
        address feed = tokenToUsdFeed[asset];
        if (feed == address(0)) return (0, priceConfig.updatedAt);
        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed);
        (, int256 rawPrice,,,) = priceFeed.latestRoundData();
        if (rawPrice <= 0) return (0, priceConfig.updatedAt);
        uint8 feedDecimals = priceFeed.decimals();
        uint256 tokenUsdPrice = uint256(rawPrice);
        uint256 flippedTokenPrice = (10 ** (feedDecimals + decimals)) / tokenUsdPrice;
        uint256 ngnPrice = priceConfig.pricePerNgn;
        return ((flippedTokenPrice * ngnPrice) / (10 ** 18), priceConfig.updatedAt);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }

    uint256[50] private __gap;
}
