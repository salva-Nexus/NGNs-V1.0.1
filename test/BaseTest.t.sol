// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { NGNS } from "../src/NGNS.sol";
import { NGNSEngine } from "../src/NGNSEngine.sol";
import { NGNOracle } from "../src/oracles/NGNOracle.sol";
import { Errors } from "../src/utils/Errors.sol";
import { MockAggregatorV3 } from "./Mocks/MockAggregatorV3.t.sol";
import { MockWETH } from "./Mocks/MockWETH.t.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test, console } from "forge-std/Test.sol";

abstract contract BaseTest is Test {
    address internal OWNER;
    address internal USERA;
    NGNSEngine internal engine;
    NGNS internal ngns;
    NGNOracle internal ngnOracle;
    MockWETH internal mockWETH;
    MockAggregatorV3 internal mockAggregatorV3ForWeth;
    uint256 internal usdPricePerNgn = 840; // 0.00084 USD per 1 NGN
    uint256 internal wethToUsdPrice = 2000e8; // 2000 USD per 1 WETH
    uint256 internal ethToDeal = 100 * 10 ** 18;
    uint256 internal wethToMint = 50 * 10 ** 18;
    uint48 internal constant BPS_SCALER = 100;

    function setUp() external {
        OWNER = makeAddr("OWNER");
        console.log(unicode"OWNER ✅                       =>                  ", OWNER);
        USERA = makeAddr("USERA");
        _changePrank(OWNER);
        ngns = new NGNS();
        console.log(unicode"NGNS ✅                        =>                  ", address(ngns));

        NGNOracle oracle = new NGNOracle();
        bytes memory oracleInitData = abi.encodeWithSelector(oracle.initialize.selector, usdPricePerNgn);
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracle), oracleInitData);
        console.log(unicode"NGN Oracle Impl ✅             =>                  ", address(oracle));
        ngnOracle = NGNOracle(address(oracleProxy));
        console.log(unicode"NGN Oracle ✅                  =>                  ", address(ngnOracle));

        engine = new NGNSEngine(address(ngns), address(ngnOracle));
        console.log(unicode"NGN Engine ✅                  =>                  ", address(engine));
        ngns.setEngine(address(engine));

        _deal(OWNER);
        mockWETH = new MockWETH();
        mockWETH.deposit{ value: wethToMint }();
        mockAggregatorV3ForWeth = new MockAggregatorV3(8, int256(wethToUsdPrice));
        console.log(unicode"WETH TOKEN ✅                  =>                  ", address(mockWETH));
        console.log(unicode"WETH PRICE FEED ✅             =>                  ", address(mockAggregatorV3ForWeth));

        bool ensureSuccess = _assertions();
        if (ensureSuccess) console.log(unicode"✅ SETUP SUCCESSFUL!!", ensureSuccess);
        else console.log(unicode"❌ SETUP FAILED", ensureSuccess);
        _stopPrank();
    }

    modifier init() {
        uint48 plainRatio = 160;
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
        _;
        _stopPrank();
    }

    function _assertions() internal view returns (bool) {
        (, int256 wethPrice,,,) = mockAggregatorV3ForWeth.latestRoundData();
        (uint256 usdPricePerNgnFromOracle,) = ngnOracle.getUsdPricePerNgn();
        return ngns.NGNS_ENGINE() == address(engine) && usdPricePerNgnFromOracle == usdPricePerNgn
            && uint256(wethPrice) == wethToUsdPrice && engine.UPGRADE_ROLE() != bytes32(0)
            && IERC20(mockWETH).balanceOf(OWNER) == wethToMint && OWNER.balance == wethToMint;
    }

    function _changePrank(address newPrank) internal {
        _stopPrank();
        vm.startPrank(newPrank);
    }

    function _stopPrank() internal {
        vm.stopPrank();
    }

    function _deal(address account) internal {
        vm.deal(account, ethToDeal);
    }

    function _newMockWeth() internal returns (MockWETH) {
        return new MockWETH();
    }

    function _newMockAggregator() internal returns (MockAggregatorV3) {
        return new MockAggregatorV3(8, int256(wethToUsdPrice));
    }
}
