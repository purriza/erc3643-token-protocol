// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";

import {IIdentityRegistry} from "../../../src/interfaces/IIdentityRegistry.sol";

/*//////////////////////////////////////////////////////////////
                            GETTERS
//////////////////////////////////////////////////////////////*/

contract IdentityRegistryGettersTest is TestSetup {

    function test_IsVerified_NoneIsFalse() public view {
        assertFalse(emissionRegistry.isVerified(user1));
    }

    function test_IsVerified_ActiveIsTrue() public {
        vm.prank(admin);
        // Bind any non-zero identity to mark user1 as verified
        emissionRegistry.setIdentity(user1, address(0x1234));
        assertTrue(emissionRegistry.isVerified(user1));
    }
}
