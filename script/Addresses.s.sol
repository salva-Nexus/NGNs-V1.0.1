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
            tokens[0] = 0x4200000000000000000000000000000000000006; // WETH
            tokens[1] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
            tokens[2] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; // DAI
        } else if (chainId == BASE_SEPOLIA) {
            tokens = new address[](2);
            tokens[0] = 0x42cb35c315665b62b4A6970C7c6030243B808111; // USDT
            tokens[1] = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC
        } else if (chainId == BNB_MAINNET) {
            tokens = new address[](3);
            tokens[0] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB
            tokens[1] = 0x55D398326F9905FFF775485246999027b3197955; // USDT
            tokens[2] = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d; // USDC
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
            feeds[0] = 0x71041DdDaD3595f92d3bC09f1915A5b2Ef13d679; // ETH/USD
            feeds[1] = address(0x7e864a3311);
            feeds[2] = address(0x71041dddad);
        } else if (chainId == BASE_SEPOLIA) {
            feeds = new address[](2);
            feeds[0] = 0x3ec8593F930EA45ea58c968260e6e9FF53FC934f; // USDT/USD Base Sepolia
            feeds[1] = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165; // USDC/USD Base Sepolia
        } else if (chainId == BNB_MAINNET) {
            feeds = new address[](3);
            feeds[0] = address(0x0567F23e32508); // BNB/USD
            feeds[1] = 0xb97aD0e74fa7d920791ef90258a63700b08352F1; // USDT/USD
            feeds[2] = 0x51591Ef1D30E8211d07675FA97950E36c5eFB478; // USDC/USD
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
        if (chainId == BASE_MAINNET) return address(0x001);
        if (chainId == BASE_SEPOLIA) return address(0x4e6A3bfa5c54f5b79274C73c8128d1f1c3651321);
        if (chainId == BNB_MAINNET) return address(0x001);
        if (chainId == BNB_TESTNET) return address(0x87f383B0a8966Fb74882b70E8CDa3523192C4B7f);
        revert("Addresses: Unsupported Chain ID");
    }

    function _getNgnOracle() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == BASE_MAINNET) return address(0x001);
        if (chainId == BASE_SEPOLIA) return address(0x6b51afD271bB46C8Ff068beAa511Fee5756Fcc66);
        if (chainId == BNB_MAINNET) return address(0x001);
        if (chainId == BNB_TESTNET) return address(0x9066888C32Fa7807C796c183E868ADb3A27Aa6CF);
        revert("Addresses: Unsupported Chain ID");
    }

    function _getAdapter() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == BASE_MAINNET) return address(0x001);
        if (chainId == BASE_SEPOLIA) return address(0x5d968c81c73ffD1D20F67E9550a6e25a022529BF);
        if (chainId == BNB_MAINNET) return address(0x001);
        if (chainId == BNB_TESTNET) return address(0xd840ba3AA8AA6e14238A6A7B52ABB94524c9f33C);
        revert("Addresses: Unsupported Chain ID");
    }

    function _getPositionMangerV1() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == BASE_MAINNET) return address(0x001);
        if (chainId == BASE_SEPOLIA) return address(0xd80877b6d1965511c011c7cEF7555260299f0c62);
        if (chainId == BNB_MAINNET) return address(0x001);
        if (chainId == BNB_TESTNET) return address(0x989823a2D4F41230ADEF80A6618Fc60Eae6d7cF4);
        revert("Addresses: Unsupported Chain ID");
    }
}
