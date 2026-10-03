# Load environment variables from .env
include .env

DEPLOY-TO-BASE-MAINNET:
	forge script script/DeployNGNS.s.sol:DeployNGNS --rpc-url ${BASE_MAINNET_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

DEPLOY-TO-BASE-TESTNET:
	forge script script/DeployNGNS.s.sol:DeployNGNS --rpc-url ${BASE_SEPOLIA_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

DEPLOY-TO-BNB-MAINNET:
	forge script script/DeployNGNS.s.sol:DeployNGNS --rpc-url ${BNB_MAINNET_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

DEPLOY-TO-BNB-TESTNET:
	forge script script/DeployNGNS.s.sol:DeployNGNS --rpc-url ${BNB_TESTNET_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

UPGRADE-ORACLE-BASE-MAINNET:
	forge script script/UpgradeNGNOracle.s.sol:UpgradeNGNOracle --rpc-url ${BASE_MAINNET_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

UPGRADE-ORACLE-BASE-TESTNET:
	forge script script/UpgradeNGNOracle.s.sol:UpgradeNGNOracle --rpc-url ${BASE_SEPOLIA_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

UPGRADE-ORACLE-BNB-MAINNET:
	forge script script/UpgradeNGNOracle.s.sol:UpgradeNGNOracle --rpc-url ${BNB_MAINNET_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

UPGRADE-ORACLE-BNB-TESTNET:
	forge script script/UpgradeNGNOracle.s.sol:UpgradeNGNOracle --rpc-url ${BNB_TESTNET_RPC_URL} --account mainKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}