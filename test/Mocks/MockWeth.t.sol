// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockWETH
/// @notice Minimal Wrapped Ether (WETH) mock for unit testing
contract MockWETH is ERC20 {
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);

    constructor() ERC20("Wrapped Ether", "WETH") { }

    /// @notice Deposit native ETH to receive 1:1 WETH
    receive() external payable {
        deposit();
    }

    /// @notice Deposit native ETH to receive 1:1 WETH
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Burn WETH to receive back 1:1 native ETH
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
        (bool success,) = payable(msg.sender).call{ value: amount }("");
        require(success, "ETH_TRANSFER_FAILED");
    }

    /// @notice Free minting helper for easy unit testing setups
    function freeMint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
