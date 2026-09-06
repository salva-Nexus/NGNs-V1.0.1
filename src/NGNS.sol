// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NGNS is ERC20 {
    address public adapter;
    error NGNs__NotAllowed();
    error NGN__AdapterAlreadyLive();

    constructor() ERC20("Salva's Nigerian Naira", "NGNS") { }

    modifier onlyAdapter() {
        _onlyAdapter();
        _;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address account, uint256 value) public {
        _mint(account, value);
    }

    function burn(address account, uint256 value) public {
        _burn(account, value);
    }

    function _onlyAdapter() internal view {
        if (msg.sender != adapter) revert NGNs__NotAllowed();
    }

    function _setAdapter(address _adapter) public {
        if (adapter != address(0)) revert NGN__AdapterAlreadyLive();
        adapter = _adapter;
    }
}
