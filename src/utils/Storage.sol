// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// VALUES AND POSITIONS ARE STORED IN NGN
abstract contract Storage {
    uint256 internal constant MIN_COLLATERAL_RATIO = 15000; // 150% in BPS
    uint256 internal constant BPS_DENOMINATOR = 10000;
    uint256 internal constant MIN_LIQ_THRESHOLD = 11500;
    uint256 internal constant DECIMAL_SCALER = 10 ** 18;
    uint256 internal constant STALE_PRICE_THRESHOLD = 2 hours;
    address internal ngns;
    address internal ngnPriceFeed;

    struct CollateralConfig {
        // FOR REFERENCE
        address priceFeed;
        uint48 customCollateralRatio;
        uint48 customLiqThreshold;
    }

    struct PositionConfig {
        // FOR REFERENCE
        uint128 collateralDeposited;
        uint128 mintedNgns;
    }
    mapping(address => bytes32) internal positionsConfig;
    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE");

    function _positionSlot(address user, address token) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            mstore(0x00, shl(0x60, user))
            mstore(0x14, shl(0x60, token))
            mstore8(0x28, positionsConfig.slot)
            slot := keccak256(0x00, 0x29)
        }
    }

    function _loadPositions(bytes32 slot)
        internal
        view
        returns (uint128 totalCollateralDeposited, uint128 totalNgnsDebt)
    {
        assembly ("memory-safe") {
            let p := sload(add(slot, 0x01))
            let mask := 0xffffffffffffffffffffffffffffffff
            totalCollateralDeposited := shr(0x80, p)
            totalNgnsDebt := and(mask, p)
        }
    }

    function _storeCollateralPosition(address token, uint128 collateralAmount, uint8 action) internal {
        bytes32 slot = _positionSlot(msg.sender, token);
        if (action == 1) {
            assembly ("memory-safe") {
                let pSlot := add(slot, 0x01)
                let packed := sload(pSlot)
                let collateral := shr(0x80, packed)
                let full :=
                    or(shl(0x80, add(collateralAmount, collateral)), and(packed, 0xffffffffffffffffffffffffffffffff))
                sstore(pSlot, full)
            }
        } else {
            assembly ("memory-safe") {
                let pSlot := add(slot, 0x01)
                let packed := sload(pSlot)
                let collateral := shr(0x80, packed)
                let full :=
                    or(shl(0x80, sub(collateral, collateralAmount)), and(packed, 0xffffffffffffffffffffffffffffffff))
                sstore(pSlot, full)
            }
        }
    }

    function _loadCollateralConfig(bytes32 slot)
        internal
        view
        returns (address priceFeed, uint48 ratio, uint48 liqThreshold)
    {
        assembly ("memory-safe") {
            let packed := sload(slot)
            priceFeed := shr(0x60, and(packed, not(0xffffffffffffffffffffffff)))
            ratio := and(shr(0x30, packed), 0xffffffffffff)
            liqThreshold := and(packed, 0xffffffffffff)
        }
    }

    function _storeCollateralConfig(address token, address priceFeedAddress, uint48 ratio, uint48 liqThreshold)
        internal
    {
        bytes32 slot = _positionSlot(msg.sender, token);
        assembly ("memory-safe") {
            let f := or(or(shl(0x60, priceFeedAddress), shl(0x30, ratio)), liqThreshold)
            sstore(slot, f)
        }
    }
}
