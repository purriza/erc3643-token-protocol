// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IdentityFactory} from "../../../src/identity/IdentityFactory.sol";
import {IIdentityFactory} from "../../../src/interfaces/IIdentityFactory.sol";

contract IdentityFactoryInitAdminHelpersTest is Test {
    address internal admin = makeAddr("admin");
    address internal complianceAdmin = makeAddr("complianceAdmin");
    address internal other = makeAddr("other");

    IdentityFactory internal identityFactory;

    function setUp() public {
        IdentityFactory impl = new IdentityFactory();
        bytes memory initData = abi.encodeCall(IdentityFactory.initialize, (admin, complianceAdmin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        identityFactory = IdentityFactory(address(proxy));
    }

    function test_Initialize_SetsExpectedRoles() public view {
        assertTrue(identityFactory.hasRole(identityFactory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(identityFactory.hasRole(identityFactory.ADMIN_ROLE(), admin));
        assertTrue(identityFactory.hasRole(identityFactory.ADMIN_ROLE(), complianceAdmin));
        assertTrue(identityFactory.hasRole(identityFactory.UPGRADER_ROLE(), admin));
    }

    function test_Initialize_DoubleCallReverts() public {
        vm.expectRevert();
        identityFactory.initialize(admin, complianceAdmin);
    }

    function test_Initialize_RevertsWhenZeroAdmin() public {
        IdentityFactory impl = new IdentityFactory();
        bytes memory initData = abi.encodeCall(IdentityFactory.initialize, (address(0), complianceAdmin));
        vm.expectRevert(IIdentityFactory.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_Initialize_RevertsWhenZeroComplianceAdmin() public {
        IdentityFactory impl = new IdentityFactory();
        bytes memory initData = abi.encodeCall(IdentityFactory.initialize, (admin, address(0)));
        vm.expectRevert(IIdentityFactory.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_Upgrade_RevertsWhenCallerIsNotUpgrader() public {
        IdentityFactory newImplementation = new IdentityFactory();
        vm.prank(other);
        vm.expectRevert();
        identityFactory.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_Upgrade_SucceedsWhenCallerHasUpgraderRole() public {
        IdentityFactory newImplementation = new IdentityFactory();
        vm.prank(admin);
        identityFactory.upgradeToAndCall(address(newImplementation), bytes(""));
    }
}

