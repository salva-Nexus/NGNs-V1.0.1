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

    function test_Purge_StandardPartialLiquidation_Success() external init {
        address borrower = USERA;
        address liquidator = OWNER;
        address receiver = makeAddr("RECEIVER");

        uint128 depositAmount = uint128(1 * 10 ** mockWETH.decimals());
        uint128 mintAmount = uint128(1_000_000 * 10 ** ngns.decimals());

        // Setup borrower position
        mockWETH.transfer(borrower, depositAmount);
        _changePrank(borrower);
        positionManager.registerCollateral(address(mockWETH), 160 * BPS_SCALER, 130 * BPS_SCALER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), depositAmount);
        positionManager.openPosition(address(mockWETH), mintAmount);
        positionManager.openPosition(address(mockWETH), uint128(100_000 * 10 ** ngns.decimals()));

        // Crash price to make position unhealthy
        mockAggregatorV3ForWeth.updateAnswer(1050e8);

        // Setup liquidator with required NGNS tokens to burn
        _changePrank(liquidator);
        mockWETH.approve(address(positionManager), depositAmount * 2);
        positionManager.depositCollateral(address(mockWETH), depositAmount * 2);
        positionManager.openPosition(address(mockWETH), mintAmount);

        uint128 liqAmount = mintAmount / 2; // Exactly 50%
        (uint256 expectedCValue, uint256 expectedBonus) = positionManager.collateralValue(address(mockWETH), liqAmount);
        uint256 expectedSeized = expectedCValue + expectedBonus;

        uint256 receiverWethBefore = mockWETH.balanceOf(receiver);

        positionManager.purge(borrower, address(mockWETH), receiver, liqAmount);

        (, PositionManager.PositionConfig memory pos) = positionManager.userConfig(borrower, address(mockWETH));
        assertEq(pos.mintedNgns, mintAmount + 100_000 * 10 ** ngns.decimals() - liqAmount);
        assertEq(mockWETH.balanceOf(receiver), receiverWethBefore + expectedSeized);
    }

    function test_Purge_DustDebt_FullLiquidation_Success() external init {
        address borrower = USERA;
        address liquidator = OWNER;
        address receiver = makeAddr("RECEIVER");
        // 1. Setup borrower position with high debt relative to 1 WETH collateral
        uint128 depositAmount = uint128(1e15);
        console.log("NGN VALUE OF 0.001 WETH: ", positionManager.ngnValue(address(mockWETH), depositAmount));
        // 1,100 NGNS total debt against 1 WETH
        uint128 initialMintAmount = uint128(1_100 * 10 ** ngns.decimals());

        mockWETH.transfer(borrower, depositAmount);
        _changePrank(borrower);
        positionManager.registerCollateral(address(mockWETH), 160 * BPS_SCALER, 130 * BPS_SCALER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), depositAmount);
        positionManager.openPosition(address(mockWETH), initialMintAmount);

        // 2. Dump WETH price to 800 USD/WETH
        uint256 h1 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H1: ", h1);
        mockAggregatorV3ForWeth.updateAnswer(1000e8);
        uint256 h2 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H2: ", h2);
        // 999999999997968

        // 3. Setup liquidator with NGNS
        _changePrank(liquidator);
        mockWETH.approve(address(positionManager), depositAmount * 4);
        positionManager.depositCollateral(address(mockWETH), depositAmount * 4);
        positionManager.openPosition(address(mockWETH), uint128(2_000 * 10 ** ngns.decimals()));

        (, PositionManager.PositionConfig memory posFinal) = positionManager.userConfig(borrower, address(mockWETH));

        // 4. First Purge: Liquidate 50% (550 NGNS). Position remains unhealthy (550 NGNS remaining > 500 NGNS floor)
        positionManager.purge(borrower, address(mockWETH), receiver, uint128(posFinal.mintedNgns) / 2);

        uint256 h3 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H3: ", h3);

        (, PositionManager.PositionConfig memory posFina2) = positionManager.userConfig(borrower, address(mockWETH));

        mockAggregatorV3ForWeth.updateAnswer(500e8);
        uint256 h4 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H4: ", h4);

        // 5. Second Purge: Liquidate 50% of 550 NGNS (275 NGNS).
        // Position remaining debt drops to 275 NGNS (which is <= MIN_DEBT_FLOOR of 500 NGNS)
        positionManager.purge(borrower, address(mockWETH), receiver, uint128(posFina2.mintedNgns) / 2);

        uint256 h5 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H5: ", h5);

        mockAggregatorV3ForWeth.updateAnswer(250e8);
        uint256 h6 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H6: ", h6);
        // 6. Third Purge (Dust Zone): Debt is now 275 NGNS (<= 500 NGNS MIN_DEBT_FLOOR).
        // Calling purge overrides to 100% full liquidation of remaining 275 NGNS debt.
        positionManager.purge(borrower, address(mockWETH), receiver, 1);

        uint256 h7 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H7: ", h7);
        (, PositionManager.PositionConfig memory posFinal3) = positionManager.userConfig(borrower, address(mockWETH));
        assertEq(posFinal3.mintedNgns, 0);
        console.log("Remaining Collateral: ", posFinal3.collateralDeposited);
        console.log("Remaining Collateral: ", posFinal3.collateralDeposited < depositAmount);
    }

    function test_Cannot_Purge_ExceedingFiftyPercentCap() external init {
        address borrower = USERA;
        address liquidator = OWNER;

        uint128 depositAmount = uint128(1 * 10 ** mockWETH.decimals());
        uint128 mintAmount = uint128(1_000_000 * 10 ** ngns.decimals());

        mockWETH.transfer(borrower, depositAmount);
        _changePrank(borrower);
        positionManager.registerCollateral(address(mockWETH), 160 * BPS_SCALER, 130 * BPS_SCALER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), depositAmount);
        positionManager.openPosition(address(mockWETH), mintAmount);
        positionManager.openPosition(address(mockWETH), uint128(100_000 * 10 ** ngns.decimals()));

        mockAggregatorV3ForWeth.updateAnswer(1050e8);

        _changePrank(liquidator);
        mockWETH.approve(address(positionManager), depositAmount * 10);
        positionManager.depositCollateral(address(mockWETH), depositAmount * 10);
        positionManager.openPosition(address(mockWETH), mintAmount);

        // Attempting to liquidate > 50% must revert
        uint128 invalidAmount = ((mintAmount + uint128(100_000 * 10 ** ngns.decimals())) / 2) + 1;
        vm.expectRevert(Errors.PM__CanOnlyLiquidatePartially.selector);
        positionManager.purge(borrower, address(mockWETH), OWNER, invalidAmount);
    }

    function test_Cannot_Purge_SelfPosition() external init {
        address borrower = USERA;

        uint128 depositAmount = uint128(1 * 10 ** mockWETH.decimals());
        uint128 mintAmount = uint128(1_000_000 * 10 ** ngns.decimals());

        mockWETH.transfer(borrower, depositAmount);
        _changePrank(borrower);
        positionManager.registerCollateral(address(mockWETH), 160 * BPS_SCALER, 130 * BPS_SCALER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), depositAmount);
        positionManager.openPosition(address(mockWETH), mintAmount);
        positionManager.openPosition(address(mockWETH), uint128(100_000 * 10 ** ngns.decimals()));

        mockAggregatorV3ForWeth.updateAnswer(1050e8);

        // Borrower trying to liquidate themselves must revert
        vm.expectRevert(Errors.PM__NotAllowed.selector);
        positionManager.purge(borrower, address(mockWETH), borrower, mintAmount / 2);
    }

    function test_Cannot_Purge_HealthyPosition() external init {
        address borrower = USERA;
        address liquidator = OWNER;

        uint128 depositAmount = uint128(10 * 10 ** mockWETH.decimals());
        uint128 mintAmount = uint128(1_000 * 10 ** ngns.decimals());

        mockWETH.transfer(borrower, depositAmount);
        _changePrank(borrower);
        positionManager.registerCollateral(address(mockWETH), 160 * BPS_SCALER, 130 * BPS_SCALER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), depositAmount);
        positionManager.openPosition(address(mockWETH), mintAmount);

        _changePrank(liquidator);
        vm.expectRevert(Errors.PM__NotAllowed.selector);
        positionManager.purge(borrower, address(mockWETH), liquidator, mintAmount / 2);
    }

    function test_Cannot_Purge_InsufficientLiquidatorBalance() external init {
        address borrower = USERA;
        address liquidator = OWNER;

        uint128 depositAmount = uint128(1 * 10 ** mockWETH.decimals());
        uint128 mintAmount = uint128(1_000_000 * 10 ** ngns.decimals());

        mockWETH.transfer(borrower, depositAmount);
        _changePrank(borrower);
        positionManager.registerCollateral(address(mockWETH), 160 * BPS_SCALER, 130 * BPS_SCALER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), depositAmount);
        positionManager.openPosition(address(mockWETH), mintAmount);
        positionManager.openPosition(address(mockWETH), uint128(100_000 * 10 ** ngns.decimals()));

        mockAggregatorV3ForWeth.updateAnswer(1050e8);

        // Liquidator has 0 NGNS balance
        _changePrank(liquidator);
        vm.expectRevert(Errors.PM__InsufficientBurnAmount.selector);
        positionManager.purge(borrower, address(mockWETH), liquidator, mintAmount / 2);
    }

    function test_Cannot_Purge_InvalidReceiver() external init {
        address borrower = USERA;
        address liquidator = OWNER;

        uint128 depositAmount = uint128(1 * 10 ** mockWETH.decimals());
        uint128 mintAmount = uint128(1_000_000 * 10 ** ngns.decimals());

        mockWETH.transfer(borrower, depositAmount);
        _changePrank(borrower);
        positionManager.registerCollateral(address(mockWETH), 160 * BPS_SCALER, 130 * BPS_SCALER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), depositAmount);
        positionManager.openPosition(address(mockWETH), mintAmount);
        positionManager.openPosition(address(mockWETH), uint128(100_000 * 10 ** ngns.decimals()));

        mockAggregatorV3ForWeth.updateAnswer(1050e8);

        _changePrank(liquidator);
        mockWETH.approve(address(positionManager), depositAmount * 2);
        positionManager.depositCollateral(address(mockWETH), depositAmount * 2);
        positionManager.openPosition(address(mockWETH), mintAmount);

        // Receiver address 0 must revert
        vm.expectRevert(Errors.PM__InvalidAddress.selector);
        positionManager.purge(borrower, address(mockWETH), address(0), mintAmount / 2);
    }

    function testFuzz_Purge_PartialLiquidationBoundaries(uint128 rawNgnsAmount) external init {
        address borrower = USERA;
        address liquidator = OWNER;

        uint128 depositAmount = uint128(1 * 10 ** mockWETH.decimals());
        uint128 mintAmount = uint128(1_000_000 * 10 ** ngns.decimals());

        uint256 h1 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H1: ", h1);
        mockWETH.transfer(borrower, depositAmount);
        _changePrank(borrower);
        positionManager.registerCollateral(address(mockWETH), 160 * BPS_SCALER, 130 * BPS_SCALER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), depositAmount);
        positionManager.openPosition(address(mockWETH), mintAmount);
        positionManager.openPosition(address(mockWETH), uint128(100_000 * 10 ** ngns.decimals()));

        uint256 h2 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H2: ", h2);

        _changePrank(liquidator);
        mockWETH.approve(address(positionManager), depositAmount * 10);
        positionManager.depositCollateral(address(mockWETH), depositAmount * 10);
        positionManager.openPosition(address(mockWETH), mintAmount);

        mockAggregatorV3ForWeth.updateAnswer(1050e8);
        uint256 h3 = positionManager.userPositionHealth(borrower, address(mockWETH), 0);
        console.log("BORROWER H3: ", h3);
        // 2380952 380952380952380000

        // Bound amount to strictly exceed 50%
        uint128 maxAllowed = (mintAmount + uint128(100_000 * 10 ** ngns.decimals())) / 2;
        vm.assume(rawNgnsAmount > maxAllowed);

        vm.expectRevert(Errors.PM__CanOnlyLiquidatePartially.selector);
        positionManager.purge(borrower, address(mockWETH), liquidator, rawNgnsAmount);
    }

    function test_USDC_PositionHealth_Precision() external init {
        uint48 scaledRatio = 150 * BPS_SCALER;
        uint48 scaledThreshold = 130 * BPS_SCALER;
        _changePrank(USERA);

        // Deposit 1,000 USDC ($1,000 USD value)
        uint128 usdcDeposit = 1_000 * 1e6;
        mockUSDC.mint(USERA, usdcDeposit);
        positionManager.registerCollateral(address(mockUSDC), scaledRatio, scaledThreshold);
        mockUSDC.approve(address(positionManager), usdcDeposit);
        positionManager.depositCollateral(address(mockUSDC), usdcDeposit);

        // Mint 500,000 NGN
        uint128 debtNgn = uint128(500_000 * 10 ** ngns.decimals());
        positionManager.openPosition(address(mockUSDC), debtNgn);

        uint256 health = positionManager.userPositionHealth(USERA, address(mockUSDC), 0);

        console.log("Position Health with USDC Collateral:", health);
        assertGt(health, 100 * BPS_SCALER);
    }

    function test_USDC_Depeg_PurgeWorkflow() external init {
        uint48 scaledRatio = 150 * BPS_SCALER;
        uint48 scaledThreshold = 130 * BPS_SCALER;

        // Setup Borrower
        _changePrank(USERA);
        uint128 usdcDeposit = 1300 * 1e6; // $1,300 USDC
        mockUSDC.mint(USERA, usdcDeposit);
        positionManager.registerCollateral(address(mockUSDC), scaledRatio, scaledThreshold);
        mockUSDC.approve(address(positionManager), usdcDeposit);
        positionManager.depositCollateral(address(mockUSDC), usdcDeposit);

        // Open position for 1,000,000 NGN
        uint128 debtNgn = uint128(1_000_000 * 10 ** ngns.decimals());
        positionManager.openPosition(address(mockUSDC), debtNgn);

        _changePrank(OWNER);
        uint128 purgeAmount = debtNgn / 2;
        address receiver = makeAddr("RECEIVER");
        mockUSDC.approve(address(positionManager), usdcDeposit);
        positionManager.depositCollateral(address(mockUSDC), usdcDeposit);
        positionManager.openPosition(address(mockUSDC), debtNgn);

        // Simulate USDC De-peg to $0.70
        uint256 h1 = positionManager.userPositionHealth(USERA, address(mockUSDC), 0);
        console.log("BORROWER H1: ", h1);
        mockAggregatorUsdcUsd.updateAnswer(70_000_000);
        uint256 h2 = positionManager.userPositionHealth(USERA, address(mockUSDC), 0);
        console.log("BORROWER H2: ", h2);

        // Liquidation check

        uint256 receiverUsdcBefore = mockUSDC.balanceOf(receiver);
        positionManager.purge(USERA, address(mockUSDC), receiver, purgeAmount);
        uint256 receiverUsdcAfter = mockUSDC.balanceOf(receiver);

        // Receiver must get paid back in 6-decimal USDC units
        assertGt(receiverUsdcAfter, receiverUsdcBefore);
    }

    /* ========================================================================= */
    /*                              WITHDRAW TESTS                               */
    /* ========================================================================= */

    function test_Withdraw_Full_WhenNoDebt_Success() external init {
        uint256 depositAmount = 10 * 10 ** mockWETH.decimals();

        _changePrank(OWNER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));

        uint256 balanceBefore = mockWETH.balanceOf(OWNER);

        positionManager.withdraw(address(mockWETH), OWNER, uint128(depositAmount));

        (, PositionManager.PositionConfig memory position) = positionManager.userConfig(OWNER, address(mockWETH));
        assertEq(position.collateralDeposited, 0);
        assertEq(mockWETH.balanceOf(OWNER), balanceBefore + depositAmount);
    }

    function test_Withdraw_Partial_WithHealthyDebt_Success() external init {
        uint256 depositAmount = 10 * 10 ** mockWETH.decimals();
        uint256 debtAmount = 500_000 * 10 ** ngns.decimals();
        uint128 withdrawAmount = uint128(2 * 10 ** mockWETH.decimals());

        _changePrank(OWNER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));
        positionManager.openPosition(address(mockWETH), uint128(debtAmount));

        uint256 h1 = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("BORROWER H1: ", h1);

        uint256 balanceBefore = mockWETH.balanceOf(OWNER);

        positionManager.withdraw(address(mockWETH), OWNER, withdrawAmount);

        uint256 h2 = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("BORROWER H2: ", h2);

        (, PositionManager.PositionConfig memory position) = positionManager.userConfig(OWNER, address(mockWETH));
        assertEq(position.collateralDeposited, depositAmount - withdrawAmount);
        assertEq(mockWETH.balanceOf(OWNER), balanceBefore + withdrawAmount);
    }

    function test_Withdraw_ToThirdPartyReceiver_Success() external init {
        uint256 depositAmount = 5 * 10 ** mockWETH.decimals();
        address recipient = makeAddr("RECIPIENT");

        _changePrank(OWNER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));

        positionManager.withdraw(address(mockWETH), recipient, uint128(depositAmount));

        assertEq(mockWETH.balanceOf(recipient), depositAmount);
    }

    function test_Cannot_Withdraw_WhenInitialPositionUndercollateralized() external init {
        uint256 depositAmount = 1 * 10 ** mockWETH.decimals();
        uint256 debtAmount = 1_000_000 * 10 ** ngns.decimals();

        _changePrank(OWNER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));
        positionManager.openPosition(address(mockWETH), uint128(debtAmount));

        uint256 h1 = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("BORROWER H1: ", h1);

        // Crash WETH price to make initial health < customCollateralRatio
        mockAggregatorV3ForWeth.updateAnswer(1300e8);

        uint256 h2 = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("BORROWER H2: ", h2);

        vm.expectRevert(Errors.PM__UndercollateralizedPosition.selector);
        positionManager.withdraw(address(mockWETH), OWNER, 1 ether);
    }

    function test_Cannot_Withdraw_WhenFinalPositionBreachesCollateralRatio() external init {
        uint256 depositAmount = 10 * 10 ** mockWETH.decimals();
        uint256 debtAmount = 1_000_000 * 10 ** ngns.decimals();

        _changePrank(OWNER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));
        positionManager.openPosition(address(mockWETH), uint128(debtAmount));
        positionManager.openPosition(address(mockWETH), uint128(debtAmount));
        positionManager.openPosition(address(mockWETH), uint128(debtAmount));
        positionManager.openPosition(address(mockWETH), uint128(debtAmount));

        uint256 h1 = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);
        console.log("BORROWER H1: ", h1);

        // Withdraw 8 WETH -> remaining 2 WETH is insufficient collateral for debtAmount
        uint128 excessiveWithdrawal = uint128(8 * 10 ** mockWETH.decimals());

        vm.expectRevert(Errors.PM__UndercollateralizedPosition.selector);
        positionManager.withdraw(address(mockWETH), OWNER, excessiveWithdrawal);
    }

    function test_Cannot_Withdraw_ToZeroAddress() external init {
        uint256 depositAmount = 5 * 10 ** mockWETH.decimals();

        _changePrank(OWNER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));

        vm.expectRevert(Errors.PM__InvalidAddress.selector);
        positionManager.withdraw(address(mockWETH), address(0), uint128(depositAmount));
    }

    function test_Cannot_Withdraw_MoreThanDeposited() external init {
        uint256 depositAmount = 5 * 10 ** mockWETH.decimals();

        _changePrank(OWNER);
        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));

        vm.expectRevert();
        positionManager.withdraw(address(mockWETH), OWNER, uint128(depositAmount) + 1);
    }

    function test_Withdraw_AtExactWithdrawableBoundary_Success() external init {
        uint256 depositAmount = 5 * 10 ** mockWETH.decimals();
        uint256 debtAmount = 1_000_000 * 10 ** ngns.decimals();

        _changePrank(OWNER);

        mockWETH.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockWETH), uint128(depositAmount));

        // No debt -> entire collateral is withdrawable
        uint256 w1 = positionManager.collateralAmountWithdrawable(OWNER, address(mockWETH));
        console.log("W1: ", w1);
        assertEq(w1, depositAmount);

        // Open debt
        positionManager.openPosition(address(mockWETH), uint128(debtAmount));

        uint256 withdrawable = positionManager.collateralAmountWithdrawable(OWNER, address(mockWETH));
        console.log("WITHDRAWABLE: ", withdrawable);

        // Withdraw exactly the maximum allowed amount
        positionManager.withdraw(address(mockWETH), OWNER, uint128(withdrawable));

        (, PositionManager.PositionConfig memory position) = positionManager.userConfig(OWNER, address(mockWETH));

        console.log("REMAINING COLLATERAL: ", position.collateralDeposited);

        // 160% collateral ratio should remain
        uint256 finalHealth = positionManager.userPositionHealth(OWNER, address(mockWETH), 0);

        console.log("FINAL HEALTH: ", finalHealth);

        assertEq(position.collateralDeposited, depositAmount - withdrawable);
        assertEq(finalHealth, 160 * BPS_SCALER);
    }

    function test_Cannot_Withdraw_AboveWithdrawableBoundary() external init {
        uint256 depositAmount = 5000 * 10 ** mockUSDC.decimals();
        uint256 debtAmount = 1_000_000 * 10 ** ngns.decimals();

        _changePrank(OWNER);

        mockUSDC.approve(address(positionManager), depositAmount);
        positionManager.depositCollateral(address(mockUSDC), uint128(depositAmount));
        uint256 withdrawable = positionManager.collateralAmountWithdrawable(OWNER, address(mockUSDC));

        console.log("WITHDRAWABLE: ", withdrawable);
        positionManager.openPosition(address(mockUSDC), uint128(debtAmount));

        uint256 withdrawable2 = positionManager.collateralAmountWithdrawable(OWNER, address(mockUSDC));

        console.log("WITHDRAWABLE 2: ", withdrawable2);

        // Even 1 wei above the calculated maximum must fail
        vm.expectRevert(Errors.PM__UndercollateralizedPosition.selector);

        positionManager.withdraw(address(mockUSDC), OWNER, uint128(withdrawable2 + 1));
    }
}
