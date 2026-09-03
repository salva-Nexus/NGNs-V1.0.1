// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title NGNS Token
/// @author Salva
/// @notice Decentralized, over-collateralized Nigerian Naira (NGNS) ERC-20
/// stablecoin
/// @dev Minting and burning access is strictly locked to the designated
/// NGNSEngine proxy
contract NGNS is ERC20 {
    address public NGNS_ENGINE;

    error NGNs__NotAllowed();
    error NGNs__InvalidAddress();
    error NGNs__EngineAlreadySet();

    modifier onlyEngine() {
        _onlyEngine();
        _;
    }

    constructor() ERC20("Nigerian Naira Salva", "NGNS") { }

    function mint(address to, uint256 amount) external onlyEngine {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyEngine {
        _burn(from, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function setEngine(address engineProxy) external {
        if (engineProxy == address(0)) revert NGNs__InvalidAddress();
        if (NGNS_ENGINE != address(0)) revert NGNs__EngineAlreadySet();
        NGNS_ENGINE = engineProxy;
    }

    function _onlyEngine() internal view {
        if (msg.sender != NGNS_ENGINE) revert NGNs__NotAllowed();
    }
}
