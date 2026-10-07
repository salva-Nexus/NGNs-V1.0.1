// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { NGNOracle } from "../src/oracles/NGNOracle.sol";
import { Addresses } from "./Addresses.s.sol";
import { Script, console } from "forge-std/Script.sol";

contract UpgradeNGNOracle is Script, Addresses {
    function run() external {
        vm.startBroadcast();
        address proxyAddress = _getNgnOracle();
        console.log(unicode"Targeting NGNOracle Proxy at:", proxyAddress);
        NGNOracle newImplementation = new NGNOracle();
        console.log(unicode"New NGNOracle Implementation deployed at:", address(newImplementation));
        NGNOracle(proxyAddress).upgradeToAndCall(address(newImplementation), "");
        console.log(unicode"✅ NGNOracle successfully upgraded to new implementation!");
        vm.stopBroadcast();
    }
}
