// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { NGNS } from "../src/NGNS.sol";
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
        ngns.whitelistCollateralToken(address(mockWETH), address(mockAggregatorV3ForWeth));
        ngns.registerCollateral(address(mockWETH), scaledToBps, thresholdScaledToBps);
        NGNS.CollateralConfig memory config = ngns.collateralConfig(OWNER, address(mockWETH));
        assertEq(config.priceFeed, address(mockAggregatorV3ForWeth));
        assertEq(config.customCollateralRatio, scaledToBps);
        assertEq(config.customLiqThreshold, thresholdScaledToBps);

        _test_cannotRegisterSameCollateral(scaledToBps, thresholdScaledToBps);
    }

    function _test_cannotRegisterSameCollateral(uint48 scaledToBps, uint48 thresholdScaledToBps) internal {
        vm.expectRevert(Errors.NGNS__CollateralLive.selector);
        ngns.registerCollateral(address(mockWETH), scaledToBps, thresholdScaledToBps);

        _test_cannotRegisterMinCollateralRatio(thresholdScaledToBps);
    }

    function _test_cannotRegisterMinCollateralRatio(uint48 thresholdScaledToBps) internal {
        address newMockWETH = address(_newMockWeth());
        address newMockAggr = address(_newMockAggregator());
        ngns.whitelistCollateralToken(address(newMockWETH), address(newMockAggr));
        for (uint48 ratio = 0; ratio < 150; ratio++) {
            vm.expectRevert(Errors.NGNS__InvalidCollateralRatio.selector);
            ngns.registerCollateral(newMockWETH, ratio * BPS_SCALER, thresholdScaledToBps);
        }
        uint48 ratioScaled = 160 * BPS_SCALER;
        _test_cannotRegisterMinThreshold(newMockWETH, ratioScaled);
    }

    function _test_cannotRegisterMinThreshold(address newMock, uint48 ratio) internal {
        for (uint48 liqThreshold = 0; liqThreshold < 115; liqThreshold++) {
            vm.expectRevert(Errors.NGNS__InvalidLiqThreshold.selector);
            ngns.registerCollateral(newMock, ratio, liqThreshold * BPS_SCALER);
        }
    }

    function test_deposit() external init {
        uint256 wethDecimals = mockWETH.decimals();
        uint256 depositAmount = 10 * 10 ** wethDecimals;
        _changePrank(OWNER);
        mockWETH.approve(address(ngns), depositAmount);
        ngns.depositCollateral(address(mockWETH), uint128(depositAmount));
        NGNS.PositionConfig memory position = ngns.positionConfig(OWNER, address(mockWETH));
        console.log("WETH DEPOSIT AMOUNT TO NAIRA VALUE: ", position.collateralDeposited);
        console.log(
            position.collateralDeposited / 10 ** mockWETH.decimals(),
            ": ",
            ngns.getNgnValue(address(mockWETH), depositAmount),
            "NGNS"
        );
        assertEq(position.collateralDeposited, depositAmount);
        assertEq(position.mintedNgns, 0);

        _test_Cannot_Deposit_Unregistered_Collateral(depositAmount);
    }

    function _test_Cannot_Deposit_Unregistered_Collateral(uint256 depositAmount) internal {
        address newMock = address(_newMockWeth());
        bytes memory data = abi.encodeWithSignature("deposit()");
        (bool success,) = newMock.call{ value: depositAmount }(data);
        console.log("MINT WETH SUCCESS: ", success);
        bytes memory data2 = abi.encodeWithSignature("approve(address,uint256)", address(ngns), depositAmount);
        (bool success2,) = newMock.call(data2);
        console.log("APPROVE SUCCESS: ", success2);
        vm.expectRevert(Errors.NGNS__UnsupportedCollateral.selector);
        ngns.depositCollateral(newMock, uint128(depositAmount));
    }

    function test_Borrow() external init {
        // deposit collateral
        uint256 wethDecimals = mockWETH.decimals();
        uint256 ngnsDecimals = ngns.decimals();
        uint256 depositAmount = 10 * 10 ** wethDecimals;
        uint256 debtAmount = 5000 * 10 ** ngnsDecimals;
        console.log("NGN VALUE OF 10 WETH: ", ngns.getNgnValue(address(mockWETH), depositAmount));
        _changePrank(OWNER);
        mockWETH.approve(address(ngns), depositAmount);
        ngns.depositCollateral(address(mockWETH), uint128(depositAmount));
        uint256 initialHealth = ngns.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("INITIAL HEALTH: ", initialHealth);

        ngns.mintNgns(address(mockWETH), uint128(debtAmount));
        (, NGNS.PositionConfig memory positions) = ngns.userConfig(OWNER, address(mockWETH));
        console.log("NGN COLLATERAL: ", positions.collateralDeposited);
        console.log("NGN DEBT: ", positions.mintedNgns);

        uint256 newHealth = ngns.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("NEW HEALTH: ", newHealth);

        assertLt(newHealth, initialHealth);

        _newBorrow(depositAmount, newHealth);
    }

    function _newBorrow(uint256 depositAmount, uint256 initialHealth) internal {
        uint256 ngnsDecimals = ngns.decimals();
        uint256 debtAmount = 14000000 * 10 ** ngnsDecimals;
        uint256 expectedNewHealth = ngns.userPositionHealth(OWNER, address(mockWETH), debtAmount);
        console.log("EXPECTED NEW HEALTH: ", expectedNewHealth);
        console.log("NGN VALUE OF 10 WETH: ", ngns.getNgnValue(address(mockWETH), depositAmount));
        _changePrank(OWNER);

        ngns.mintNgns(address(mockWETH), uint128(debtAmount));
        (, NGNS.PositionConfig memory positions) = ngns.userConfig(OWNER, address(mockWETH));
        console.log("NGN COLLATERAL: ", positions.collateralDeposited);
        console.log("NGN DEBT: ", positions.mintedNgns);

        uint256 newHealth = ngns.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("NEW HEALTH: ", newHealth);

        assertLt(newHealth, initialHealth);
        _test_Price_Drop(newHealth);
    }

    function _test_Price_Drop(uint256 initialHealth) internal {
        // Price drop 20%
        console.log("INITIAL HEALTH: ", initialHealth);
        int256 newPrice = 1600e8;
        mockAggregatorV3ForWeth.updateAnswer(newPrice);
        uint256 newHealth = ngns.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("NEW HEALTH: ", newHealth);

        assertLt(newHealth, initialHealth);

        _test_Ngn_Devaluation(newHealth);
    }

    function _test_Ngn_Devaluation(uint256 initialHealth) internal {
        console.log("INITIAL HEALTH: ", initialHealth);
        (uint256 initUsdPrice,) = ngnOracle.getUsdPricePerNgn();
        console.log("INITIAL USD PER NGN PRICE: ", initUsdPrice);
        uint256 newPrice = 410;
        ngnOracle.updatePrice(newPrice);
        (uint256 newUsdPrice,) = ngnOracle.getUsdPricePerNgn();
        console.log("NEW USD PER NGN PRICE: ", newUsdPrice);
        uint256 newHealth = ngns.userPositionHealth(OWNER, address(mockWETH), 0);

        assertGt(newHealth, initialHealth);
        console.log("NEW HEALTH: ", newHealth);
    }

    function test_shift() external pure {
        bytes32 f;
        assembly ("memory-safe") {
            f := or(shl(0x80, 15000), 13000)
        }

        console.logBytes32(f);
        // 23809523800000
    }
}
