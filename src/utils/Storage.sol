// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Storage {
    uint256 internal constant MIN_COLLATERAL_RATIO = 15000; // 150% in BPS
    uint256 internal constant BPS_DENOMINATOR = 10000;
    address internal ngnsToken;
    address internal ngnPriceFeed;
    address internal positions;

    struct CollateralConfig {
        address priceFeed;
        uint80 collateralRatio;
        uint16 isSupported;
        uint128 totalDepositedCollateral;
        uint128 totalMintedNgns;
    }
    mapping(address => CollateralConfig) internal collateralConfigs;
    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE");

    function _positionSlot(address user, address token) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            mstore(0x00, shl(0x60, user))
            mstore(0x14, shl(0x60, token))
            mstore8(0x28, positions.slot)
            slot := keccak256(0x00, 0x29)
        }
    }

    function _loadPositions(bytes32 slot)
        internal
        view
        returns (uint256 totalCollateralDeposited, uint256 totalNgnsDebt)
    {
        assembly ("memory-safe") {
            let p := sload(slot)
            let mask := 0xffffffffffffffffffffffffffffffff
            totalCollateralDeposited := shr(0x80, p)
            totalNgnsDebt := and(mask, p)
        }
    }

    function _storePositions(address user, address token, uint128 collateralAmount, uint128 ngnsAmount)
        internal
        returns (bool)
    {
        bytes32 slot = _positionSlot(user, token);
        (uint256 collateral, uint256 ngns) = _loadPositions(slot);
        assembly ("memory-safe") {
            let top := shl(0x80, add(collateralAmount, collateral))
            let full := or(top, add(ngnsAmount, ngns))
            sstore(slot, full)
        }
        return true;
    }
}
