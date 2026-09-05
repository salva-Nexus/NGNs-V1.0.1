// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Modifier {
    // ─────────────────────────────────────────────────────────────────────────
    // REENTRANCY GUARD (EIP-1153 transient storage)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Guards against reentrant calls using transient storage slot `0x00`.
     * @dev Uses `tload` / `tstore` (EIP-1153) for gas-efficient locking that is
     *      automatically cleared at transaction end. Reverts with empty data on
     *      reentrant entry to minimise gas cost of the revert.
     *
     *      Lock diagram:
     *        Entry  → tload(0x00) == 0  → tstore(0x00, 1) → execute body
     *        Re-entry → tload(0x00) == 1 → revert(0,0)
     *        Exit   → tstore(0x00, 0)   (cleared for next call in same tx)
     */
    modifier nonReentrant() {
        assembly {
            if gt(tload(0x00), 0x00) {
                mstore(0x00, 0x57352948) // NGN_Reentrancy
                revert(0x00, 0x04)
            }
            tstore(0x00, 0x01)
        }
        _;
        // assembly {
        //     tstore(0x00, 0x00) // will comment out during deployment, this is just for test
        // }
    }
}
