// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Adapter } from "../src/Adapter.sol";
import { NGNS } from "../src/NGNS.sol";
import { PositionManager } from "../src/PositionManager.sol";
import { NGNOracle } from "../src/oracles/NGNOracle.sol";
import { Addresses } from "./Addresses.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployNGNS is Script, Addresses {
    function run() external returns (NGNS ngns, Adapter adapter, NGNOracle ngnOracle, PositionManager positionManager) {
        uint256 mintCap = 5_000_000 * 10 ** 18;
        uint256 usdPricePerNgn = 840000000000000;

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
        ngnOracle.grantRole(ngnOracle.PRICE_UPDATE_ROLE(), address(0xfD5A9828bac27495FAb7F6174b3de386E0554187));
        ngnOracle.updatePrice(usdPricePerNgn);
        ngnOracle.setTokenUsdFeed(address(0), address(0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7)); // ETH/USD
        ngnOracle.setTokenUsdFeed(
            address(0xb07B89CF7495306D418131123b04a9A616616228), address(0xEca2605f0BCF2BA5966372C99837b1F182d3D620)
        ); // USDT/USD
        // 2. Deploy NGNS Token
        ngns = new NGNS();
        console.log("NGNS Token       :", address(ngns), block.chainid);

        // 3. Deploy Adapter
        adapter = new Adapter(address(ngns));
        console.log("Adapter          :", address(adapter));

        // 4. Link Adapter to NGNS
        ngns.setAdapter(address(adapter));
        console.log(unicode"Adapter Linked to NGNS ✅");

        // 6. Deploy PositionManager
        positionManager = new PositionManager(
            address(ngns), address(ngnOracle), address(adapter), _getTokens(), _getPriceFeeds(), mintCap
        );
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

