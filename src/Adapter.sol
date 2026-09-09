// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

interface INGNS {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

/// @title Position Adapter
/// @notice Middleman contract regulating supply caps and PositionManager authorizations for NGNS minting/burning.
contract Adapter is AccessControl {
    bytes32 public constant MANAGER_ADMIN_ROLE = keccak256("MANAGER_ADMIN_ROLE");
    uint256 public constant MANAGER_MINT_CAP = 1_000_000 * 10 ** 6;

    INGNS public immutable ngns;

    mapping(address positionManager => bool isAllowed) public isPositionManager;

    error Adapter__NotPositionManager();
    error Adapter__ZeroAddress();
    error Adapter__MintAmountExceedsLimit(uint256 amount, uint256 cap);

    event PositionManagerStatusUpdated(address indexed manager, bool indexed status);

    modifier onlyPositionManager() {
        _onlyPositionManager();
        _;
    }

    constructor(address _ngns) {
        if (_ngns == address(0)) revert Adapter__ZeroAddress();

        ngns = INGNS(_ngns);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ADMIN_ROLE, msg.sender);
    }

    function setPositionManager(address manager, bool status) external onlyRole(MANAGER_ADMIN_ROLE) {
        if (manager == address(0)) revert Adapter__ZeroAddress();
        isPositionManager[manager] = status;
        emit PositionManagerStatusUpdated(manager, status);
    }

    function supply(address to, uint256 amount) external onlyPositionManager {
        if (amount > MANAGER_MINT_CAP) {
            revert Adapter__MintAmountExceedsLimit(amount, MANAGER_MINT_CAP);
        }
        ngns.mint(to, amount);
    }

    function repay(address from, uint256 amount) external onlyPositionManager {
        ngns.burn(from, amount);
    }

    function _onlyPositionManager() internal view {
        if (!isPositionManager[msg.sender]) {
            revert Adapter__NotPositionManager();
        }
    }
}
