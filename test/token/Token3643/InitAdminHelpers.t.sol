// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";

import {Token3643} from "../../../src/token/Token3643.sol";
import {IToken3643} from "../../../src/interfaces/IToken3643.sol";

/*//////////////////////////////////////////////////////////////
                    INIT / ADMIN / HELPERS
//////////////////////////////////////////////////////////////*/

contract Token3643InitAdminHelpersTest is TestSetup {

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR / ROLES
    //////////////////////////////////////////////////////////////*/

    function test_EmissionToken_HasExpectedRoles() public view {
        assertTrue(emissionToken.hasRole(emissionToken.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(emissionToken.hasRole(emissionToken.ADMIN_ROLE(), admin));
        assertTrue(emissionToken.hasRole(emissionToken.COMPLIANCE_ADMIN_ROLE(), admin));
        assertTrue(emissionToken.hasRole(emissionToken.AGENT_ROLE(), admin));
    }

    function test_EmissionToken_RegistryAndComplianceSet() public view {
        assertEq(address(emissionToken.registry()), address(emissionRegistry));
        assertEq(address(emissionToken.compliance()), address(emissionCompliance));
        assertEq(emissionToken.treasury(), treasuryWallet);
    }

    function test_EmissionToken_InitialSupplyMinted() public view {
        assertEq(emissionToken.totalSupply(), DEFAULT_INITIAL_SUPPLY);
    }

    function test_Constructor_RevertsWhenAnyCriticalAddressIsZero() public {
        vm.expectRevert(IToken3643.ZeroAddress.selector);
        new Token3643(
            "TestToken",
            "TT",
            address(0),
            address(emissionCompliance),
            treasuryWallet,
            admin,
            admin,
            admin,
            1 ether
        );

        vm.expectRevert(IToken3643.ZeroAddress.selector);
        new Token3643(
            "TestToken",
            "TT",
            address(emissionRegistry),
            address(0),
            treasuryWallet,
            admin,
            admin,
            admin,
            1 ether
        );

        vm.expectRevert(IToken3643.ZeroAddress.selector);
        new Token3643(
            "TestToken",
            "TT",
            address(emissionRegistry),
            address(emissionCompliance),
            address(0),
            admin,
            admin,
            admin,
            1 ether
        );

        vm.expectRevert(IToken3643.ZeroAddress.selector);
        new Token3643(
            "TestToken",
            "TT",
            address(emissionRegistry),
            address(emissionCompliance),
            treasuryWallet,
            address(0),
            admin,
            admin,
            1 ether
        );

        vm.expectRevert(IToken3643.ZeroAddress.selector);
        new Token3643(
            "TestToken",
            "TT",
            address(emissionRegistry),
            address(emissionCompliance),
            treasuryWallet,
            admin,
            address(0),
            admin,
            1 ether
        );

        vm.expectRevert(IToken3643.ZeroAddress.selector);
        new Token3643(
            "TestToken",
            "TT",
            address(emissionRegistry),
            address(emissionCompliance),
            treasuryWallet,
            admin,
            admin,
            address(0),
            1 ether
        );
    }
}
