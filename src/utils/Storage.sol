// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Storage {
    bytes32 public constant COLLATERAL_MANAGER_ROLE = keccak256("COLLATERAL_MANAGER_ROLE");

    uint256 public constant MIN_COLLATERAL_RATIO = 15000; // 150% in BPS
    uint256 public constant MIN_LIQ_THRESHOLD = 11500;
    uint256 public constant LIQ_BONUS = 10; // 10%

    uint256 internal constant BPS_DENOMINATOR = 10000;
    uint256 internal constant DECIMAL_SCALER = 10 ** 18;
    uint256 internal constant STALE_PRICE_THRESHOLD = 2 hours;
    uint256 internal constant PERCENTAGE_SCALER = 100;

    address internal immutable ngns;
    address internal immutable ngnPriceFeed;
    address internal immutable adapter;

    struct CollateralConfig {
        address priceFeed;
        uint48 customCollateralRatio;
        uint48 customLiqThreshold;
    }

    struct PositionConfig {
        uint128 collateralDeposited;
        uint128 mintedNgns;
    }

    mapping(address => bytes32) internal positionsConfig;
    mapping(address token => address priceFeed) public allowedCollateralFeeds;

    function _positionSlot(address user, address token) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            mstore(0x00, shl(0x60, user))
            mstore(0x14, shl(0x60, token))
            mstore8(0x28, positionsConfig.slot)
            slot := keccak256(0x00, 0x29)
        }
    }

    function _loadPositionsConfig(bytes32 slot)
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

    function _updateCollateralValue(address user, address token, uint128 collateralAmount, uint8 action) internal {
        bytes32 slot = _positionSlot(user, token);
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
                if gt(collateralAmount, collateral) {
                    revert(0x00, 0x00)
                }
                let full :=
                    or(shl(0x80, sub(collateral, collateralAmount)), and(packed, 0xffffffffffffffffffffffffffffffff))
                sstore(pSlot, full)
            }
        }
    }

    function _updateDebtValue(address user, address token, uint128 debtAmount, uint8 action) internal {
        bytes32 slot = _positionSlot(user, token);
        if (action == 1) {
            assembly ("memory-safe") {
                let pSlot := add(slot, 0x01)
                let packed := sload(pSlot)
                let debt := and(packed, 0xffffffffffffffffffffffffffffffff)
                let full := or(add(debtAmount, debt), and(packed, not(0xffffffffffffffffffffffffffffffff)))
                sstore(pSlot, full)
            }
        } else {
            assembly ("memory-safe") {
                let pSlot := add(slot, 0x01)
                let packed := sload(pSlot)
                let debt := and(packed, 0xffffffffffffffffffffffffffffffff)
                if gt(debtAmount, debt) {
                    revert(0x00, 0x00)
                }
                let full := or(sub(debt, debtAmount), and(packed, not(0xffffffffffffffffffffffffffffffff)))
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

    function _updateCollateralConfig(address user, address token, uint48 ratio, uint48 liqThreshold) internal {
        bytes32 slot = _positionSlot(user, token);
        assembly ("memory-safe") {
            let packed := sload(slot)

            // Case 1: Update BOTH if both are > 0
            if and(gt(ratio, 0x00), gt(liqThreshold, 0x00)) {
                let f :=
                    or(
                        or(shl(0x30, ratio), and(liqThreshold, 0xffffffffffff)),
                        and(packed, not(0xffffffffffffffffffffffff))
                    )
                sstore(slot, f)
            }

            // Case 2: Update ONLY ratio (if ratio > 0 and liqThreshold == 0)
            if and(gt(ratio, 0x00), iszero(gt(liqThreshold, 0x00))) {
                let r := shl(0x30, ratio)
                let mask := 0xffffffffffffffffffffffffffffffffffffffff000000000000ffffffffffff
                let p := and(packed, mask)
                let f := or(p, r)
                sstore(slot, f)
            }

            // Case 3: Update ONLY liqThreshold (if liqThreshold > 0 and ratio == 0)
            if and(gt(liqThreshold, 0x00), iszero(gt(ratio, 0x00))) {
                let mask := not(0xffffffffffff)
                let p := and(packed, mask)
                let f := or(p, and(liqThreshold, 0xffffffffffff))
                sstore(slot, f)
            }
        }
    }

    function _storeCollateralConfig(
        address user,
        address token,
        address priceFeedAddress,
        uint48 ratio,
        uint48 liqThreshold
    ) internal {
        bytes32 slot = _positionSlot(user, token);
        assembly ("memory-safe") {
            let f := or(or(shl(0x60, priceFeedAddress), shl(0x30, ratio)), liqThreshold)
            sstore(slot, f)
        }
    }
}
