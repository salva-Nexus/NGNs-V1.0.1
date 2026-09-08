// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { PositionManager } from "../src/PositionManager.sol";
import { Errors } from "../src/utils/Errors.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { console } from "forge-std/console.sol";

contract PM is BaseTest {
    function test_register_collateral() external {
        uint48 plainRatio = 150;
        uint48 scaledToBps = plainRatio * BPS_SCALER;
        uint48 plainThreshold = 130;
        uint48 thresholdScaledToBps = plainThreshold * BPS_SCALER;
        _changePrank(OWNER);
        positionManager.registerCollateral(address(mockWETH), scaledToBps, thresholdScaledToBps);
        PositionManager.CollateralConfig memory config = positionManager.collateralConfig(OWNER, address(mockWETH));
        assertEq(config.priceFeed, address(mockAggregatorV3ForWeth));
        assertEq(config.customCollateralRatio, scaledToBps);
        assertEq(config.customLiqThreshold, thresholdScaledToBps);

        _test_cannotRegisterSameCollateral(scaledToBps, thresholdScaledToBps);
    }

    function _test_cannotRegisterSameCollateral(uint48 scaledToBps, uint48 thresholdScaledToBps) internal {
        vm.expectRevert(Errors.PM__CollateralLive.selector);
        positionManager.registerCollateral(address(mockWETH), scaledToBps, thresholdScaledToBps);
    }

    function test_cannotRegisterMinCollateralRatio() external {
        uint48 plainThreshold = 130;
        uint48 thresholdScaledToBps = plainThreshold * BPS_SCALER;
        _changePrank(OWNER);
        for (uint48 ratio = 0; ratio < 150; ratio++) {
            vm.expectRevert(Errors.PM__InvalidCollateralRatio.selector);
            positionManager.registerCollateral(address(mockWETH), ratio * BPS_SCALER, thresholdScaledToBps);
        }
        uint48 ratioScaled = 160 * BPS_SCALER;
        _test_cannotRegisterMinThreshold(ratioScaled);
    }

    function _test_cannotRegisterMinThreshold(uint48 ratio) internal {
        for (uint48 liqThreshold = 0; liqThreshold < 115; liqThreshold++) {
            vm.expectRevert(Errors.PM__InvalidLiqThreshold.selector);
            positionManager.registerCollateral(address(mockWETH), ratio, liqThreshold * BPS_SCALER);
        }
    }

    function test_deposit() external init {
        uint256 wethDecimals = mockWETH.decimals();
        uint256 depositAmount = 10 * 10 ** wethDecimals;
        _changePrank(OWNER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));
        PositionManager.PositionConfig memory position = positionManager.positionConfig(OWNER, address(mockWETH));
        console.log("WETH DEPOSIT AMOUNT TO NAIRA VALUE: ", position.collateralDeposited);
        console.log(
            position.collateralDeposited / 10 ** mockWETH.decimals(),
            ": ",
            positionManager.ngnValue(address(mockWETH), depositAmount),
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
        bytes memory data2 =
            abi.encodeWithSignature("approve(address,uint256)", address(positionManager), depositAmount);
        (bool success2,) = newMock.call(data2);
        console.log("APPROVE SUCCESS: ", success2);
        vm.expectRevert(Errors.PM__UnregisteredCollateral.selector);
        positionManager.depositCollateral(newMock, uint128(depositAmount));
    }

    function test_Open_Position() external init {
        // deposit collateral
        uint256 wethDecimals = mockWETH.decimals();
        uint256 ngnsDecimals = ngns.decimals();
        uint256 depositAmount = 10 * 10 ** wethDecimals;
        uint256 debtAmount = 5000 * 10 ** ngnsDecimals;
        console.log("NGN VALUE OF 10 WETH: ", positionManager.ngnValue(address(mockWETH), depositAmount));
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));
        uint256 initialHealth = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("INITIAL HEALTH: ", initialHealth);

        positionManager.openPosition(address(mockWETH), uint128(debtAmount));
        (, PositionManager.PositionConfig memory positions) = positionManager.userConfig(OWNER, address(mockWETH));
        console.log("NGN COLLATERAL: ", positions.collateralDeposited);
        console.log("NGN DEBT: ", positions.mintedNgns);

        uint256 newHealth = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("NEW HEALTH: ", newHealth);

        assertLt(newHealth, initialHealth);

        _newBorrow(depositAmount, newHealth);
    }

    function _newBorrow(uint256 depositAmount, uint256 initialHealth) internal {
        uint256 ngnsDecimals = ngns.decimals();
        uint256 debtAmount = 900_000 * 10 ** ngnsDecimals;
        uint256 expectedNewHealth = positionManager.userPositionHealth(OWNER, address(mockWETH), debtAmount);
        console.log("EXPECTED NEW HEALTH: ", expectedNewHealth);
        console.log("NGN VALUE OF 10 WETH: ", positionManager.ngnValue(address(mockWETH), depositAmount));

        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.openPosition(address(mockWETH), uint128(debtAmount));
        (, PositionManager.PositionConfig memory positions) = positionManager.userConfig(OWNER, address(mockWETH));
        console.log("NGN COLLATERAL: ", positions.collateralDeposited);
        console.log("NGN DEBT: ", positions.mintedNgns);

        uint256 newHealth = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("NEW HEALTH: ", newHealth);

        assertLt(newHealth, initialHealth);
        _test_Price_Drop(newHealth);
    }

    function _test_Price_Drop(uint256 initialHealth) internal {
        // Price drop 20%
        console.log("INITIAL HEALTH: ", initialHealth);
        int256 newPrice = 1600e8;
        mockAggregatorV3ForWeth.updateAnswer(newPrice);
        uint256 newHealth = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
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
        uint256 newHealth = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);

        assertGt(newHealth, initialHealth);
        console.log("NEW HEALTH: ", newHealth);
    }

    function test_Settle_Debt() external init {
        // DEPOSIT COLLATERAL AND MINT DEBT

        _changePrank(OWNER);
        uint256 wethDecimals = mockWETH.decimals();
        uint256 ngnsDecimals = ngns.decimals();
        uint256 depositAmount = 10 * 10 ** wethDecimals;
        uint256 debtAmount = 1_000_000 * 10 ** ngnsDecimals;
        console.log("NGN VALUE OF 10 WETH: ", positionManager.ngnValue(address(mockWETH), depositAmount));
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));
        uint256 initialHealth = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("INITIAL HEALTH: ", initialHealth);

        positionManager.openPosition(address(mockWETH), uint128(debtAmount));
        (, PositionManager.PositionConfig memory positions) = positionManager.userConfig(OWNER, address(mockWETH));
        console.log("NGN COLLATERAL: ", positions.collateralDeposited);
        console.log("NGN DEBT: ", positions.mintedNgns);

        uint256 newHealth = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("NEW HEALTH: ", newHealth);

        assertLt(newHealth, initialHealth);

        positionManager.settlePosition(address(mockWETH), uint128(debtAmount) / 2);
        (, PositionManager.PositionConfig memory positionsAfterSettleMent) =
            positionManager.userConfig(OWNER, address(mockWETH));
        console.log("NGN DEBT AFTER SETTLEMENT: ", positionsAfterSettleMent.mintedNgns);

        uint256 newHealthAfterSettlement = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("NEW HEALTH AFTER SETTLEMENT: ", newHealthAfterSettlement);

        assertGt(newHealthAfterSettlement, newHealth);

        _test_Underflow(debtAmount);
    }

    function _test_Underflow(uint256 amount) internal {
        vm.expectRevert();
        positionManager.settlePosition(address(mockWETH), uint128(amount) * 2);
    }

    function test_Purge_Success() external init {
        uint48 plainRatio = 150;
        uint48 scaledToBps = plainRatio * BPS_SCALER;
        uint48 plainThreshold = 130;
        uint48 thresholdScaledToBps = plainThreshold * BPS_SCALER;

        address borrower = USERA;
        address liquidator = OWNER;
        address receiver = makeAddr("RECEIVER");

        uint128 depositAmount = uint128(1 * 10 ** mockWETH.decimals());
        mockWETH.transfer(borrower, depositAmount);
        _changePrank(borrower);
        positionManager.registerCollateral(address(mockWETH), scaledToBps, thresholdScaledToBps);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), depositAmount);
        (, PositionManager.PositionConfig memory positions) = positionManager.userConfig(borrower, address(mockWETH));
        console.log("BORROWER CD 1: ", positions.collateralDeposited);
        console.log("BORROWER DB 1: ", positions.mintedNgns);
        uint256 h1 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H1: ", h1);
        uint256 nValue = positionManager.ngnValue(address(mockWETH), depositAmount);
        console.log("NGN VALUE: ", nValue);

        uint128 mintAmount = uint128(1_000_000 * 10 ** ngns.decimals());
        positionManager.openPosition(address(mockWETH), mintAmount);
        uint256 h2 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H2: ", h2);

        // Simulate WETH/USD price 25% drop
        int256 newPrice = 1500e8;
        mockAggregatorV3ForWeth.updateAnswer(newPrice);
        uint256 h3 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H3: ", h3);
        // borrower opens another position
        uint128 newMintAmount = uint128(100_000 * 10 ** ngns.decimals());
        positionManager.openPosition(address(mockWETH), newMintAmount);

        uint256 h4 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H4: ", h4);

        // still healthy, cannot liquidate
        // Prepare Liq
        // liquidate up to 50% of the debtors position
        uint128 liqAmount = mintAmount / 2;
        uint256 initialLiquidatorWethBalance = mockWETH.balanceOf(liquidator);
        console.log("INITIAL WETH BALANCE OF LIQUIDATOR", initialLiquidatorWethBalance);
        _changePrank(liquidator);
        mockWETH.approve(address(positionManager), depositAmount * 10); // 10 WETH a collateral
        positionManager.depositCollateral(address(mockWETH), depositAmount * 10);
        positionManager.openPosition(address(mockWETH), mintAmount);
        uint256 initialLiquidatorNgnBalance = ngns.balanceOf(liquidator);
        console.log("INITIAL NGNS BALANCE OF LIQUIDATOR", initialLiquidatorNgnBalance);

        vm.expectRevert(Errors.PM__NotAllowed.selector);
        positionManager.purge(borrower, address(mockWETH), receiver, liqAmount);

        // Simulate WETH/USD price drops another 30%
        int256 newPrice2 = 1050e8;
        mockAggregatorV3ForWeth.updateAnswer(newPrice2);
        uint256 h5 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H5: ", h5);

        (PositionManager.CollateralConfig memory config2,) = positionManager.userConfig(borrower, address(mockWETH));
        assertLt(h5, config2.customLiqThreshold);

        // Perform Purge not position is unhealthy
        (uint256 cValue, uint256 liqBonus) = positionManager.collateralValue(address(mockWETH), liqAmount);
        console.log("EXPECTED CVALUE AND BONUS FOR liquidator", cValue, liqBonus);
        positionManager.purge(borrower, address(mockWETH), receiver, liqAmount);

        (, PositionManager.PositionConfig memory positions2) = positionManager.userConfig(borrower, address(mockWETH));
        uint256 h6 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H6: ", h6); // now above min threshold, but still at risk
        console.log("BORROWER CD 2: ", positions2.collateralDeposited);
        uint256 newLiquidatorNgnBalance = ngns.balanceOf(liquidator);
        console.log("NEW NGNS BALANCE OF LIQUIDATOR", newLiquidatorNgnBalance);
        // assertions
        assertEq(mockWETH.balanceOf(receiver), cValue + liqBonus);
        assertLt(positions2.collateralDeposited, positions.collateralDeposited);
        assertEq(positions2.collateralDeposited, positions.collateralDeposited - (cValue + liqBonus));
        assertLt(ngns.balanceOf(liquidator), initialLiquidatorNgnBalance);

        // WONT WORK BECUASE ITS NOW ABOVE global MIN_LIQ_THRES, but still below custome liq thres, so in grace state
        vm.expectRevert(Errors.PM__NotAllowed.selector);
        positionManager.purge(borrower, address(mockWETH), receiver, liqAmount / 2);
    }

    function test_UpdateCollateralConfig_AutoRegister_Unregistered() external init {
        _changePrank(USERA);
        address token = address(mockWETH);

        uint48 newRatio = 170 * BPS_SCALER;
        uint48 newThreshold = 140 * BPS_SCALER;

        // Route fallback should trigger registerCollateral
        positionManager.updateCollateralConfig(token, newRatio, newThreshold);

        (PositionManager.CollateralConfig memory config,) = positionManager.userConfig(USERA, token);
        assertEq(config.customCollateralRatio, newRatio);
        assertEq(config.customLiqThreshold, newThreshold);
        assertEq(config.priceFeed, address(mockAggregatorV3ForWeth));
    }

    function test_UpdateCollateralConfig_Assembly_Both() external init {
        _changePrank(USERA);
        address token = address(mockWETH);

        positionManager.registerCollateral(token, 160 * BPS_SCALER, 130 * BPS_SCALER);

        uint48 updatedRatio = 180 * BPS_SCALER;
        uint48 updatedThreshold = 150 * BPS_SCALER;

        positionManager.updateCollateralConfig(token, updatedRatio, updatedThreshold);

        (PositionManager.CollateralConfig memory config,) = positionManager.userConfig(USERA, token);
        assertEq(config.customCollateralRatio, updatedRatio);
        assertEq(config.customLiqThreshold, updatedThreshold);
    }

    function test_UpdateCollateralConfig_Assembly_OnlyRatio() external init {
        _changePrank(USERA);
        address token = address(mockWETH);

        uint48 initialRatio = 160 * BPS_SCALER;
        uint48 initialThreshold = 130 * BPS_SCALER;
        positionManager.registerCollateral(token, initialRatio, initialThreshold);

        uint48 newRatio = 190 * BPS_SCALER;

        positionManager.updateCollateralConfig(token, newRatio, 0);

        (PositionManager.CollateralConfig memory config,) = positionManager.userConfig(USERA, token);
        assertEq(config.customCollateralRatio, newRatio);
        assertEq(config.customLiqThreshold, initialThreshold);
    }

    function test_UpdateCollateralConfig_Assembly_OnlyThreshold() external init {
        _changePrank(USERA);
        address token = address(mockWETH);

        uint48 initialRatio = 160 * BPS_SCALER;
        uint48 initialThreshold = 130 * BPS_SCALER;
        positionManager.registerCollateral(token, initialRatio, initialThreshold);

        uint48 newThreshold = 145 * BPS_SCALER;

        positionManager.updateCollateralConfig(token, 0, newThreshold);

        (PositionManager.CollateralConfig memory config,) = positionManager.userConfig(USERA, token);
        assertEq(config.customCollateralRatio, initialRatio);
        assertEq(config.customLiqThreshold, newThreshold);
    }

    function test_Cannot_UpdateCollateralConfig_WhenInDebt() external init {
        uint128 depositAmount = uint128(2 * 10 ** mockWETH.decimals());
        uint128 mintAmount = uint128(100_000 * 10 ** ngns.decimals());

        mockWETH.transfer(USERA, depositAmount);
        _changePrank(USERA);
        address token = address(mockWETH);

        positionManager.registerCollateral(token, 160 * BPS_SCALER, 130 * BPS_SCALER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(token, depositAmount);
        positionManager.openPosition(token, mintAmount);

        vm.expectRevert(Errors.PM__CannotModifyParametersWithActiveDebt.selector);
        positionManager.updateCollateralConfig(token, 180 * BPS_SCALER, 140 * BPS_SCALER);
    }

    function test_Cannot_UpdateCollateralConfig_InvalidRatio() external init {
        _changePrank(USERA);
        address token = address(mockWETH);
        positionManager.registerCollateral(token, 160 * BPS_SCALER, 130 * BPS_SCALER);

        uint48 invalidRatio = 120 * BPS_SCALER; // Below MIN_COLLATERAL_RATIO (150)

        vm.expectRevert(Errors.PM__InvalidCollateralRatio.selector);
        positionManager.updateCollateralConfig(token, invalidRatio, 130 * BPS_SCALER);
    }

    function test_Cannot_UpdateCollateralConfig_InvalidThreshold() external init {
        _changePrank(USERA);
        address token = address(mockWETH);
        positionManager.registerCollateral(token, 160 * BPS_SCALER, 130 * BPS_SCALER);

        uint48 invalidThreshold = 100 * BPS_SCALER; // Below MIN_LIQ_THRESHOLD (115)

        vm.expectRevert(Errors.PM__InvalidLiqThreshold.selector);
        positionManager.updateCollateralConfig(token, 160 * BPS_SCALER, invalidThreshold);
    }

    function test_Cannot_UpdateCollateralConfig_InvalidBuffer() external init {
        _changePrank(USERA);
        address token = address(mockWETH);
        positionManager.registerCollateral(token, 160 * BPS_SCALER, 130 * BPS_SCALER);

        uint48 ratio = 150 * BPS_SCALER;
        uint48 invalidThreshold = 155 * BPS_SCALER; // threshold >= ratio

        vm.expectRevert(Errors.PM__InvalidThresholdBuffer.selector);
        positionManager.updateCollateralConfig(token, ratio, invalidThreshold);
    }

    function testFuzz_updateCollateralConfig_validBoundaries(uint48 ratio, uint48 threshold) external init {
        _changePrank(USERA);
        address token = address(mockWETH);
        positionManager.registerCollateral(token, 160 * BPS_SCALER, 130 * BPS_SCALER);

        // Bound parameters within safe operational limits
        vm.assume(ratio > 150 * BPS_SCALER);
        vm.assume(ratio < 500 * BPS_SCALER);
        vm.assume(threshold < ratio);
        vm.assume(threshold > 115 * BPS_SCALER);

        positionManager.updateCollateralConfig(token, ratio, threshold);

        PositionManager.CollateralConfig memory config = positionManager.collateralConfig(USERA, token);
        assertEq(config.customCollateralRatio, ratio);
        assertEq(config.customLiqThreshold, threshold);
    }

    function testFuzz_RevertIf_updateCollateralConfig_ratioBelowMin(uint48 ratio, uint48 threshold) external init {
        _changePrank(USERA);
        address token = address(mockWETH);
        positionManager.registerCollateral(token, 160 * BPS_SCALER, 130 * BPS_SCALER);

        // Bound ratio to strictly below MIN_COLLATERAL_RATIO (150 * BPS_SCALER)
        // Bound threshold to valid limits so only the ratio triggers the revert
        vm.assume(ratio > 0);
        vm.assume(ratio < 150 * BPS_SCALER);
        vm.assume(threshold < 150 * BPS_SCALER);
        vm.assume(threshold > 115 * BPS_SCALER);

        vm.expectRevert(Errors.PM__InvalidCollateralRatio.selector);
        positionManager.updateCollateralConfig(token, ratio, threshold);
    }

    function test_shift() public pure {
        bytes32 s;
        bytes32 l;
        bytes32 m;
        bytes32 f;
        assembly {
            s := 0x1111111111111111111111111111111111111111000000444444000000555555
            l := not(0xffffffffffff)
            m := and(s, l)
            f := or(m, 0x000000999999)
        }

        console.logBytes32(s);
        console.logBytes32(l);
        console.logBytes32(m);
        console.logBytes32(f);
    }
}
