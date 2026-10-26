// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IdentityRegistry} from "../../../src/identity/IdentityRegistry.sol";
import {IIdentityRegistry} from "../../../src/interfaces/IIdentityRegistry.sol";

/*//////////////////////////////////////////////////////////////
                    INIT / ADMIN / HELPERS
//////////////////////////////////////////////////////////////*/

contract IdentityRegistryInitAdminHelpersTest is TestSetup {

    /*//////////////////////////////////////////////////////////////
                            ROLES
    //////////////////////////////////////////////////////////////*/

    function test_EmissionRegistry_HasRoles() public view {
        assertTrue(emissionRegistry.hasRole(emissionRegistry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(emissionRegistry.hasRole(emissionRegistry.COMPLIANCE_ADMIN_ROLE(), admin));
        assertTrue(emissionRegistry.hasRole(emissionRegistry.UPGRADER_ROLE(), admin));
    }

    function test_IdentityOf_DefaultIsZero() public view {
        assertEq(emissionRegistry.identityOf(user1), address(0));
    }

    function test_Upgrade_RevertsWhenCallerIsNotUpgrader() public {
        IdentityRegistry newImplementation = new IdentityRegistry();
        vm.prank(user1);
        vm.expectRevert();
        emissionRegistry.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_Upgrade_SucceedsWhenCallerHasUpgraderRole() public {
        IdentityRegistry newImplementation = new IdentityRegistry();
        vm.prank(admin);
        emissionRegistry.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_Initialize_RevertsWhenAdminIsZeroAddress() public {
        IdentityRegistry impl = new IdentityRegistry();
        // Use any non-zero placeholders for the registries; the initialize should revert on the zero admin first.
        address claimTopicsRegistry = address(0xA11CE);
        address claimsRegistry = address(0xB0B);

        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(IdentityRegistry.initialize, (address(0), admin, claimTopicsRegistry, claimsRegistry))
        );
    }

    function test_Initialize_RevertsWhenComplianceAdminIsZeroAddress() public {
        IdentityRegistry impl = new IdentityRegistry();
        address claimTopicsRegistry = address(0xA11CE);
        address claimsRegistry = address(0xB0B);

        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(IdentityRegistry.initialize, (admin, address(0), claimTopicsRegistry, claimsRegistry))
        );
    }

    function test_Initialize_RevertsWhenClaimTopicsRegistryIsZeroAddress() public {
        IdentityRegistry impl = new IdentityRegistry();

        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(IdentityRegistry.initialize, (admin, admin, address(0), address(0xB0B)))
        );
    }

    function test_Initialize_RevertsWhenClaimsRegistryIsZeroAddress() public {
        IdentityRegistry impl = new IdentityRegistry();

        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(IdentityRegistry.initialize, (admin, admin, address(0xA11CE), address(0)))
        );
    }

    function test_EmissionRegistry_WiredToClaimRegistries() public view {
        assertTrue(address(emissionRegistry.claimTopicsRegistry()) != address(0));
        assertTrue(address(emissionRegistry.claimsRegistry()) != address(0));
    }
}
