// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { BaseTest } from "./BaseTest.t.sol";
import { console } from "forge-std/Test.sol";

contract NGNSTest is BaseTest {
    function test_PermitGaslessApproval() public {
        // 1. Setup a test wallet with a known private key
        uint256 userPrivateKey = 0xA11CE;
        address user = vm.addr(userPrivateKey);
        address spender = makeAddr("SPENDER");
        uint256 amount = 1_000 * 10 ** 18; // 1,000 NGNS
        uint256 deadline = block.timestamp + 1 hours;

        // 2. Fetch the current nonce and domain separator
        uint256 nonce = ngns.nonces(user);
        bytes32 domainSeparator = ngns.DOMAIN_SEPARATOR();

        // 3. Construct EIP-712 Struct Hash for Permit
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, user, spender, amount, nonce, deadline));

        // 4. Compute Digest and Sign with Private Key
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        // 5. Execute Permit (Gasless approval submission by any relayer)
        vm.prank(spender);
        ngns.permit(user, spender, amount, deadline, v, r, s);

        // 6. Assertions
        assertEq(ngns.allowance(user, spender), amount);
        assertEq(ngns.nonces(user), nonce + 1);

        console.log(unicode"NGNS Permit Approval ✅ => Spender Allowance:", ngns.allowance(user, spender));
    }
}
