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
        console.log("NGN Oracle IMPL :", address(oracleImpl));
        ngnOracle.grantRole(ngnOracle.PRICE_UPDATE_ROLE(), address(0x9Da6C69815A2b9FFe7eE08A0be00EF181881Ad71));
        ngnOracle.updatePrice(usdPricePerNgn);
        ngnOracle.setTokenUsdFeed(address(0), address(0xd5D290Fe2ae6b55F385ab9C14d2CeB91DD3d9022)); // ETH/USD
        ngnOracle.setTokenUsdFeed(
            address(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d), address(0x8068600c8f6d2fB3d44F5B4cb7E7f4Ac47c2c742)
        );
        ngnOracle.setTokenUsdFeed(
            address(0x55D398326F9905FFF775485246999027b3197955), address(0x501e21126486424567f40D490856094D72986E41)
        );
        ngnOracle.setTokenUsdFeed(
            address(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD), address(0xca236E327F629f9Fc2c30A4E95775EbF0B89fac8)
        );
        // 2. Deploy NGNS Token
        ngns = new NGNS();
        console.log("NGNS Token       :", address(ngns), block.chainid);

        // 3. Deploy Adapter
        adapter = new Adapter(address(ngns));
        console.log("Adapter          :", address(adapter));

        // // 4. Link Adapter to NGNS
        ngns.setAdapter(address(adapter));
        console.log(unicode"Adapter Linked to NGNS ✅");

        // 6. Deploy PositionManager
        positionManager = new PositionManager(
            address(ngns), address(ngnOracle), address(adapter), _getTokens(), _getPriceFeeds(), mintCap, "v2"
        );
        console.log("PositionManager  :", address(positionManager));

        // 7. Authorize PositionManager inside Adapter
        adapter.setPositionManager(address(positionManager), true);
        adapter.grantRole(adapter.MANAGER_ADMIN_ROLE(), address(0xBCdE35307e897625E39915B200Be0A0a17088Da6));
        console.log(unicode"PositionManager Authorized on Adapter ✅");

        vm.stopBroadcast();

        console.log("==================================================");
        console.log("           ALL CORE CONTRACTS LIVE                ");
        console.log("==================================================");
    }
}

