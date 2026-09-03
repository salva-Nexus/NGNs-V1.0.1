// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { NGNSEngine } from "../src/NGNSEngine.sol";
import { Errors } from "../src/utils/Errors.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { console } from "forge-std/console.sol";

contract Engine is BaseTest {
    function test_register_collateral() external {
        uint80 plainRatio = 150;
        uint80 scaledToBps = plainRatio * BPS_SCALER;
        engine.registerCollateral(address(mockWETH), address(mockAggregatorV3ForWeth), scaledToBps);
        NGNSEngine.CollateralConfig memory config = engine.collateralConfig(address(mockWETH));
        console.log("WETH FEED DATA", config.priceFeed);
        assertEq(config.priceFeed, address(mockAggregatorV3ForWeth));
        assertEq(config.isSupported, 1);
        assertEq(config.collateralRatio, scaledToBps);

        _test_cannotRegisterSameCollateral(scaledToBps);
    }

    function _test_cannotRegisterSameCollateral(uint80 scaledBps) internal {
        vm.expectRevert(Errors.NGNSEngine__CollateralLive.selector);
        engine.registerCollateral(address(mockWETH), address(mockAggregatorV3ForWeth), scaledBps);

        _test_cannotRegisterMinCollateralRatio();
    }

    function _test_cannotRegisterMinCollateralRatio() internal {
        engine.unregisterCollateral(address(mockWETH));
        NGNSEngine.CollateralConfig memory config = engine.collateralConfig(address(mockWETH));
        assertEq(config.isSupported, 0);

        for (uint80 ratio = 0; ratio < 150; ratio++) {
            vm.expectRevert(Errors.NGNSEngine__InvalidCollateralRatio.selector);
            engine.registerCollateral(address(mockWETH), address(mockAggregatorV3ForWeth), ratio * BPS_SCALER);
        }

        _test_reregister();
    }

    function _test_reregister() internal {
        uint80 plainRatio = 200;
        uint80 scaledToBps = plainRatio * BPS_SCALER;
        engine.registerCollateral(address(mockWETH), address(mockAggregatorV3ForWeth), scaledToBps);
        NGNSEngine.CollateralConfig memory config = engine.collateralConfig(address(mockWETH));
        console.log("WETH FEED DATA", config.priceFeed);
        assertEq(config.priceFeed, address(mockAggregatorV3ForWeth));
        assertEq(config.isSupported, 1);
        assertEq(config.collateralRatio, scaledToBps);
    }

    function test_deposit() external init {
        console.log("===================DEPOSIT LOGS====================");
        uint256 wethDecimals = mockWETH.decimals();
        uint256 depositAmount = 10 * 10 ** wethDecimals;
        console.log("WETH DECIMALS                  =>                  ", wethDecimals);
        console.log("AMOUNT TO DEPOSIT (TO WEI)     =>                  ", depositAmount);
        _changePrank(OWNER);
        mockWETH.approve(address(engine), depositAmount);
        (uint256 initialDepositedCollateral, uint256 initialNgnDebt) = engine.position(OWNER, address(mockWETH));
        console.log("INITIAL COLLATERAL             =>                  ", initialDepositedCollateral);
        console.log("INITIAL NGN DEBT               =>                  ", initialNgnDebt);
        engine.depositCollateral(address(mockWETH), uint128(depositAmount));

        (uint256 newDepositedCollateral, uint256 newNgnDebt) = engine.position(OWNER, address(mockWETH));
        console.log("NEW COLLATERAL                 =>                  ", newDepositedCollateral);
        console.log("NEW NGN DEBT                   =>                  ", newNgnDebt);

        assertEq(initialDepositedCollateral, 0);
        assertEq(initialNgnDebt, 0);
        assertEq(newDepositedCollateral, depositAmount);
        assertEq(newNgnDebt, 0);

        _test_New_Deposit(depositAmount);
    }

    function _test_New_Deposit(uint256 depositAmount) internal {
        console.log("AMOUNT TO DEPOSIT (TO WEI) 2   =>                  ", depositAmount);
        _changePrank(OWNER);
        (uint256 initialDepositedCollateral, uint256 initialNgnDebt) = engine.position(OWNER, address(mockWETH));
        mockWETH.approve(address(engine), depositAmount);
        console.log("INITIAL COLLATERAL 2           =>                  ", initialDepositedCollateral);
        console.log("INITIAL NGN DEBT   2           =>                  ", initialNgnDebt);
        engine.depositCollateral(address(mockWETH), uint128(depositAmount));

        (uint256 newDepositedCollateral, uint256 newNgnDebt) = engine.position(OWNER, address(mockWETH));
        console.log("NEW COLLATERAL      2          =>                  ", newDepositedCollateral);
        console.log("NEW NGN DEBT        2          =>                  ", newNgnDebt);
        console.log("TOTAL WETH HELD IN ENGINE      =>                  ", mockWETH.balanceOf(address(engine)));
        assertEq(initialDepositedCollateral, depositAmount);
        assertEq(initialNgnDebt, 0);
        assertEq(newDepositedCollateral, depositAmount * 2);
        assertEq(newNgnDebt, 0);
        assertEq(mockWETH.balanceOf(address(engine)), depositAmount * 2);
        assertEq(mockWETH.balanceOf(OWNER), wethToMint - depositAmount * 2);
    }
}
