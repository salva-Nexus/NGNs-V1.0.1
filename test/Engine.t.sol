// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { NGNSEngine } from "../src/NGNSEngine.sol";
import { Errors } from "../src/utils/Errors.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { console } from "forge-std/console.sol";

contract Engine is BaseTest {
    function test_register_collateral() external {
        uint48 plainRatio = 150;
        uint48 scaledToBps = plainRatio * BPS_SCALER;
        uint48 plainThreshold = 130;
        uint48 thresholdScaledToBps = plainThreshold * BPS_SCALER;
        _changePrank(OWNER);
        engine.registerCollateral(
            address(mockWETH), address(mockAggregatorV3ForWeth), scaledToBps, thresholdScaledToBps
        );
        NGNSEngine.CollateralConfig memory config =
            engine.collateralConfig(OWNER, address(mockWETH));
        assertEq(config.priceFeed, address(mockAggregatorV3ForWeth));
        assertEq(config.customCollateralRatio, scaledToBps);
        assertEq(config.customLiqThreshold, thresholdScaledToBps);

        _test_cannotRegisterSameCollateral(scaledToBps, thresholdScaledToBps);
    }

    function _test_cannotRegisterSameCollateral(uint48 scaledToBps, uint48 thresholdScaledToBps)
        internal
    {
        vm.expectRevert(Errors.NGNSEngine__CollateralLive.selector);
        engine.registerCollateral(
            address(mockWETH), address(mockAggregatorV3ForWeth), scaledToBps, thresholdScaledToBps
        );

        _test_cannotRegisterMinCollateralRatio(thresholdScaledToBps);
    }

    function _test_cannotRegisterMinCollateralRatio(uint48 thresholdScaledToBps) internal {
        address newMockWETH = address(_newMockWeth());
        address newMockAggr = address(_newMockAggregator());
        for (uint48 ratio = 0; ratio < 150; ratio++) {
            vm.expectRevert(Errors.NGNSEngine__InvalidCollateralRatio.selector);
            engine.registerCollateral(
                newMockWETH, newMockAggr, ratio * BPS_SCALER, thresholdScaledToBps
            );
        }
        uint48 ratioScaled = 160 * BPS_SCALER;
        _test_cannotRegisterMinThreshold(newMockWETH, newMockAggr, ratioScaled);
    }

    function _test_cannotRegisterMinThreshold(address newMock, address newMockAggr, uint48 ratio)
        internal
    {
        for (uint48 liqThreshold = 0; liqThreshold < 115; liqThreshold++) {
            vm.expectRevert(Errors.NGNSEngine__InvalidLiqThreshold.selector);
            engine.registerCollateral(newMock, newMockAggr, ratio, liqThreshold * BPS_SCALER);
        }
    }

    function test_deposit() external init {
        uint256 wethDecimals = mockWETH.decimals();
        uint256 depositAmount = 10 * 10 ** wethDecimals;
        _changePrank(OWNER);
        mockWETH.approve(address(engine), depositAmount);
        engine.depositCollateral(address(mockWETH), uint128(depositAmount));
        NGNSEngine.PositionConfig memory position = engine.positions(OWNER, address(mockWETH));
        assertEq(position.collateralDeposited, depositAmount);
        assertEq(position.mintedNgns, 0);

        _test_New_Deposit(depositAmount);
    }

    function _test_New_Deposit(uint256 depositAmount) internal {
        mockWETH.approve(address(engine), depositAmount);
        engine.depositCollateral(address(mockWETH), uint128(depositAmount));
        NGNSEngine.PositionConfig memory position = engine.positions(OWNER, address(mockWETH));
        assertEq(position.collateralDeposited, depositAmount * 2);
        assertEq(position.mintedNgns, 0);
        assertEq(mockWETH.balanceOf(address(engine)), depositAmount * 2);
        assertEq(mockWETH.balanceOf(OWNER), wethToMint - depositAmount * 2);

        _test_Cannot_Deposit_Unregistered_Collateral(depositAmount);
    }

    function _test_Cannot_Deposit_Unregistered_Collateral(uint256 depositAmount) internal {
        address newMock = address(_newMockWeth());
        bytes memory data = abi.encodeWithSignature("deposit()");
        (bool success,) = newMock.call{ value: depositAmount }(data);
        console.log("MINT WETH SUCCESS: ", success);
        bytes memory data2 = abi.encodeWithSignature("approve()", address(engine), depositAmount);
        (bool success2,) = newMock.call(data2);
        console.log("APPROVE SUCCESS: ", success2);
        vm.expectRevert(Errors.NGNSEngine__UnsupportedCollateral.selector);
        engine.depositCollateral(newMock, uint128(depositAmount));
    }

    function test_shift() external pure {
        bytes32 top;
        bytes32 collateralAmount;
        bytes32 collateral;
        bytes32 full;

        assembly {
            top := 0x1111111111111111111111111111111122222222222222222222222222222222
            collateralAmount := 51234

            collateral := shr(0x80, top)
            full := or(
                shl(0x80, add(collateralAmount, collateral)),
                and(top, 0xffffffffffffffffffffffffffffffff)
            )
        }

        console.logBytes32(top);
        console.logBytes32(collateralAmount);
        console.logBytes32(collateral);
        console.logBytes32(full);
    }
}
