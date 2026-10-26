// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ComplianceBase} from "../../../src/compliance/ComplianceBase.sol";
import {IComplianceBase} from "../../../src/interfaces/IComplianceBase.sol";

/*//////////////////////////////////////////////////////////////
                    INIT / ADMIN / HELPERS
//////////////////////////////////////////////////////////////*/

contract ComplianceBaseInitAdminHelpersTest is TestSetup {

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialize_RevertsWhenAnyCriticalAddressIsZero() public {
        ComplianceBase impl = new ComplianceBase();

        vm.expectRevert(IComplianceBase.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), abi.encodeCall(ComplianceBase.initialize, (address(0), admin, treasuryWallet)));

        vm.expectRevert(IComplianceBase.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), abi.encodeCall(ComplianceBase.initialize, (admin, address(0), treasuryWallet)));

        vm.expectRevert(IComplianceBase.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), abi.encodeCall(ComplianceBase.initialize, (admin, admin, address(0))));
    }

    function test_EmissionCompliance_HasRolesAndTreasury() public view {
        assertTrue(emissionCompliance.hasRole(emissionCompliance.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(emissionCompliance.hasRole(emissionCompliance.ADMIN_ROLE(), admin));
        assertTrue(emissionCompliance.hasRole(emissionCompliance.PAUSER_ROLE(), admin));
        assertEq(emissionCompliance.treasury(), treasuryWallet);
        assertFalse(emissionCompliance.paused());
    }

    function test_Upgrade_RevertsWhenCallerIsNotUpgrader() public {
        ComplianceBase newImplementation = new ComplianceBase();
        vm.prank(user1);
        vm.expectRevert();
        emissionCompliance.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_Upgrade_SucceedsWhenCallerHasUpgraderRole() public {
        ComplianceBase newImplementation = new ComplianceBase();
        vm.prank(admin);
        emissionCompliance.upgradeToAndCall(address(newImplementation), bytes(""));
    }
}
