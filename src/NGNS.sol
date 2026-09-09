// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title NGNS Stablecoin
/// @notice Synthetic NGN stablecoin minted and burned solely by the Adapter protocol engine.
contract NGNS is ERC20 {
    address public adapter;

    error NGNS__NotAllowed();
    error NGNS__AdapterAlreadyLive();
    error NGNS__ZeroAddress();

    event AdapterSet(address indexed adapter);

    constructor() ERC20("Salva's Nigerian Naira", "NGNS") { }

    modifier onlyAdapter() {
        _onlyAdapter();
        _;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function setAdapter(address _adapter) external {
        if (adapter != address(0)) revert NGNS__AdapterAlreadyLive();
        if (_adapter == address(0)) revert NGNS__ZeroAddress();
        adapter = _adapter;
        emit AdapterSet(_adapter);
    }

    function mint(address account, uint256 value) external onlyAdapter {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyAdapter {
        _burn(account, value);
    }

    function _onlyAdapter() internal view {
        if (msg.sender != adapter) revert NGNS__NotAllowed();
    }
}
