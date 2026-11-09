// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Addresses {
    // ------------------------------------------------------------------------
    // Chain ID Constants
    // ------------------------------------------------------------------------
    uint256 internal constant BASE_MAINNET = 8453;
    uint256 internal constant BASE_SEPOLIA = 84532;
    uint256 internal constant BNB_MAINNET = 56;
    uint256 internal constant BNB_TESTNET = 97;
    // ------------------------------------------------------------------------
    // Token Arrays
    // ------------------------------------------------------------------------

    function _getTokens() internal view returns (address[] memory tokens) {
        uint256 chainId = block.chainid;

        if (chainId == BASE_MAINNET) {
            tokens = new address[](3);
            tokens[0] = 0x0000000000000000000000000000000000000000; // ETH
            tokens[1] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
            tokens[2] = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2; // USDT
        } else if (chainId == BASE_SEPOLIA) {
            tokens = new address[](3);
            tokens[0] = 0x42cb35c315665b62b4A6970C7c6030243B808111; // USDT
            tokens[1] = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC
            tokens[2] = address(0); // ETH
        } else if (chainId == BNB_MAINNET) {
            tokens = new address[](3);
            tokens[0] = 0x0000000000000000000000000000000000000000; // BNB
            tokens[1] = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d; // USDC
            tokens[2] = 0x55d398326f99059fF775485246999027B3197955; // USDT
        } else if (chainId == BNB_TESTNET) {
            tokens = new address[](2);
            tokens[0] = 0x07437dC615BC4295BA9E658a2B30915ea220bC65; // USDT
            tokens[1] = 0xb07B89CF7495306D418131123b04a9A616616228; // USDC
        } else {
            revert("Addresses: Unsupported Chain ID");
        }
    }

    // ------------------------------------------------------------------------
    // Price Feed Arrays (1-to-1 index mapping with _getTokens())
    // ------------------------------------------------------------------------

    function _getPriceFeeds() internal view returns (address[] memory feeds) {
        uint256 chainId = block.chainid;

        if (chainId == BASE_MAINNET) {
            feeds = new address[](3);
            feeds[0] = address(0x50015f8b17fb2C290Dde41fDc246ed0dcEE93a8b); // ETH/USD
            feeds[1] = address(0xd0Dc8c910565D94D408729D16bE5467B5d7633Ad); // USDC/USD
            feeds[2] = address(0xE6c6bf78308C46bad5Cae5D0ed44b36370b4B00d); // USDT/USD
        } else if (chainId == BASE_SEPOLIA) {
            feeds = new address[](3);
            feeds[0] = 0x3ec8593F930EA45ea58c968260e6e9FF53FC934f; // USDT/USD Base Sepolia
            feeds[1] = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165; // USDC/USD Base Sepolia
            feeds[2] = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1; // ETH/USD
        } else if (chainId == BNB_MAINNET) {
            feeds = new address[](3);
            feeds[0] = address(0xd5D290Fe2ae6b55F385ab9C14d2CeB91DD3d9022); // BNB/USD
            feeds[1] = address(0x8068600c8f6d2fB3d44F5B4cb7E7f4Ac47c2c742); // USDC/USD
            feeds[2] = address(0x501e21126486424567f40D490856094D72986E41); // USDT/USD
        } else if (chainId == BNB_TESTNET) {
            feeds = new address[](2);
            feeds[0] = 0xEca2605f0BCF2BA5966372C99837b1F182d3D620; // USDT/USD Testnet
            feeds[1] = 0x90c069C4538adAc136E051052E14c1cD799C41B7; // USDC/USD Testnet
        } else {
            revert("Addresses: Unsupported Chain ID");
        }
    }

    function _getNgns() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == BASE_MAINNET) return address(0x79d61b73Ec980638ea4Efef7C5637aE37f596c6f);
        if (chainId == BASE_SEPOLIA) return address(0x4e6A3bfa5c54f5b79274C73c8128d1f1c3651321);
        if (chainId == BNB_MAINNET) return address(0x80C2436b19BD1fbCc5c35375D5d5Ff1FB28Ae323);
        if (chainId == BNB_TESTNET) return address(0x4A9D58566A5F778e090c78258f0C54189a1095Ae);
        revert("Addresses: Unsupported Chain ID");
    }

    function _getNgnOracle() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == BASE_MAINNET) return address(0xf0Ed0652d5150606a84C7EF9726d9585478532Bc);
        if (chainId == BASE_SEPOLIA) return address(0x6b51afD271bB46C8Ff068beAa511Fee5756Fcc66);
        if (chainId == BNB_MAINNET) return address(0x97F0BCA29304E39936dbf4C58b887DEAE5D9A75B);
        if (chainId == BNB_TESTNET) return address(0x3Ad5c68BF82bB402F81379124DCf513015CAafF1);
        revert("Addresses: Unsupported Chain ID");
    }

    function _getAdapter() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == BASE_MAINNET) return address(0x308a8C74ab07e5d2eB89ba7244E089B31642a86d);
        if (chainId == BASE_SEPOLIA) return address(0x5d968c81c73ffD1D20F67E9550a6e25a022529BF);
        if (chainId == BNB_MAINNET) return address(0x05FD44F2f1bfBd1bC3DF0CAE0002ffb49EAc2057);
        if (chainId == BNB_TESTNET) return address(0xF143e7BCf336d4bAcc15531A561b6f5476807934);
        revert("Addresses: Unsupported Chain ID");
    }

    function _getPositionMangerV1() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == BASE_MAINNET) return address(0xe698C6D97F722993a7cf4830289ABA9dfe85EDB9);
        if (chainId == BASE_SEPOLIA) return address(0x98c8C7BFfECDE502E8f9764F8C2Dc0b87509DEc0);
        if (chainId == BNB_MAINNET) return address(0x1638056996B3e902f4888380C1c83f2362153B6E);
        if (chainId == BNB_TESTNET) return address(0x75C95a8421A7d07fb9f56D2F833f404A835b70c3);
        revert("Addresses: Unsupported Chain ID");
    }
}
