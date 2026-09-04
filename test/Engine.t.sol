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
        NGNSEngine.CollateralConfig memory config = engine.collateralConfig(OWNER, address(mockWETH));
        assertEq(config.priceFeed, address(mockAggregatorV3ForWeth));
        assertEq(config.customCollateralRatio, scaledToBps);
        assertEq(config.customLiqThreshold, thresholdScaledToBps);

        _test_cannotRegisterSameCollateral(scaledToBps, thresholdScaledToBps);
    }

    function _test_cannotRegisterSameCollateral(uint48 scaledToBps, uint48 thresholdScaledToBps) internal {
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
            engine.registerCollateral(newMockWETH, newMockAggr, ratio * BPS_SCALER, thresholdScaledToBps);
        }
        uint48 ratioScaled = 160 * BPS_SCALER;
        _test_cannotRegisterMinThreshold(newMockWETH, newMockAggr, ratioScaled);
    }

    function _test_cannotRegisterMinThreshold(address newMock, address newMockAggr, uint48 ratio) internal {
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
        console.log("WETH DEPOSIT AMOUNT TO NAIRA VALUE: ", position.collateralDeposited);
        console.log(
            position.collateralDeposited / 10 ** mockWETH.decimals(),
            ": ",
            engine.getNgnValue(address(mockWETH), address(mockAggregatorV3ForWeth), depositAmount),
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
        bytes memory data2 = abi.encodeWithSignature("approve(address,uint256)", address(engine), depositAmount);
        (bool success2,) = newMock.call(data2);
        console.log("APPROVE SUCCESS: ", success2);
        vm.expectRevert(Errors.NGNSEngine__UnsupportedCollateral.selector);
        engine.depositCollateral(newMock, uint128(depositAmount));
    }

    function test_shift() external pure {
        // GET PRICE OF 1 COLLATERAL IN USD - eg 1WETH = $2000 => 200000000000
        uint256 collateralAmount = 100e18; // WETH AMOUNT
        int256 price = 2000e8; // FROM CHAINLINK
        // GET PRICE OF 1 NGN IN USD - eg 1NGN = 0.00084 USD => 840
        uint256 usdPricePerNgn = 840;
        // GET NGN ORACLE DECIMALS => 6
        uint8 ngnOracleDecimals = 6;
        uint8 chainlinkFeedDecimals = 8;
        // TO GET WHAT 1 USD IS IN NGN => 1/USDPRICEPERNGN = 1 / 0.00084 = 1e6 / USDPRICEPERNGN = 1190476190 =>
        // 1190.476190
        uint256 ngnPricePerUsd = (10 ** ngnOracleDecimals * 10 ** ngnOracleDecimals) / usdPricePerNgn;
        // TO GET THE USD PRICE OF THE INPUTTED COLLATERAL AMOUNT - amount * usdPrice = 100 WETH * 2000 USD = 200,000
        // 100e18 * 200000000000 = 200000 00000000000000000000000000
        uint256 collaterAmountToUsd = collateralAmount * uint256(price);
        // NOW DERIVE THE NGN VALUE OF THE COLLATERAL USD VALUE
        // (20000000000000000000000000000000 * 1190476190) / (1e8 * 1e6) = 238095238000000000000000000 (238,095,238)
        uint256 collaterAmountToNgn =
            (collaterAmountToUsd * ngnPricePerUsd) / (10 ** chainlinkFeedDecimals * 10 ** ngnOracleDecimals);

        // NOW GET THE ABSOLUTELY VALUE SCALED TO THE DECIMALS OF NGNS CONTRACT
        // (238095238000000000000000000 * 1e6) / 1e18 = 238095238000000 = 238,095,238 NGN = 1 WETH
        uint8 ngnsDecimals = 6;
        uint8 collateralDecimals = 18;
        uint256 ngnValue = (collaterAmountToNgn * 10 ** ngnsDecimals) / 10 ** collateralDecimals;

        console.log("Collateral Amount to Ngn: ", ngnValue);
        console.log("Collateral Amount Scaled To Absolute RW Value: ", ngnValue / 10 ** ngnsDecimals);
    }
}
