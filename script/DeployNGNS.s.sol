// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Adapter } from "../src/Adapter.sol";
import { NGNS } from "../src/NGNS.sol";
import { PositionManager } from "../src/PositionManager.sol";
import { NGNOracle } from "../src/oracles/NGNOracle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeploySalvaCore is Script {
    function run() external returns (NGNS ngns, Adapter adapter, NGNOracle ngnOracle, PositionManager positionManager) {
        address usdcToken = address(0x036CbD53842c5426634e7929541eC2318f3dCF7e); // BASE SEP
        address usdcPriceFeed = address(0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165); // BASE SEP
        uint256 mintCap = 5_000_000 * 10 ** 18;
        uint256 usdPricePerNgn = 84000;

        console.log("==================================================");
        console.log("               NGNS CORE DEPLOYMENT               ");
        console.log("==================================================");

        vm.startBroadcast();

        // 1. Deploy NGN Oracle Implementation + Proxy
        NGNOracle oracleImpl = new NGNOracle();
        bytes memory oracleInitData = abi.encodeWithSelector(oracleImpl.initialize.selector, usdPricePerNgn);
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracleImpl), oracleInitData);
        ngnOracle = NGNOracle(address(oracleProxy));
        console.log("NGN Oracle Proxy :", address(ngnOracle));

        // 2. Deploy NGNS Token
        ngns = new NGNS();
        console.log("NGNS Token       :", address(ngns));

        // 3. Deploy Adapter
        adapter = new Adapter(address(ngns));
        console.log("Adapter          :", address(adapter));

        // 4. Link Adapter to NGNS
        ngns.setAdapter(address(adapter));
        console.log(unicode"Adapter Linked to NGNS ✅");

        // 5. Build Token & Price Feed Arrays for PositionManager
        address[] memory tokens = new address[](1);
        tokens[0] = usdcToken;

        address[] memory priceFeeds = new address[](1);
        priceFeeds[0] = usdcPriceFeed;

        // 6. Deploy PositionManager
        positionManager =
            new PositionManager(address(ngns), address(ngnOracle), address(adapter), tokens, priceFeeds, mintCap);
        console.log("PositionManager  :", address(positionManager));

        // 7. Authorize PositionManager inside Adapter
        adapter.setPositionManager(address(positionManager), true);
        console.log(unicode"PositionManager Authorized on Adapter ✅");

        vm.stopBroadcast();

        console.log("==================================================");
        console.log("           ALL CORE CONTRACTS LIVE                ");
        console.log("==================================================");
    }
}
