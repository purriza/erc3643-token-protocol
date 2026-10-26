// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TrustedIssuersRegistry} from "../../../src/claims/TrustedIssuersRegistry.sol";
import {ITrustedIssuersRegistry} from "../../../src/interfaces/ITrustedIssuersRegistry.sol";

contract TrustedIssuersRegistryInitAdminHelpersTest is Test {
    address internal admin = makeAddr("admin");
    address internal complianceAdmin = makeAddr("complianceAdmin");
    address internal other = makeAddr("other");

    TrustedIssuersRegistry internal trustedIssuersRegistry;

    function setUp() public {
        TrustedIssuersRegistry impl = new TrustedIssuersRegistry();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(TrustedIssuersRegistry.initialize, (admin, complianceAdmin)));
        trustedIssuersRegistry = TrustedIssuersRegistry(address(proxy));
    }

    function test_Initialize_RevertsWhenAdminIsZeroAddress() public {
        TrustedIssuersRegistry impl = new TrustedIssuersRegistry();
        vm.expectRevert(ITrustedIssuersRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl), abi.encodeCall(TrustedIssuersRegistry.initialize, (address(0), complianceAdmin))
        );
    }

    function test_Initialize_RevertsWhenComplianceAdminIsZeroAddress() public {
        TrustedIssuersRegistry impl = new TrustedIssuersRegistry();
        vm.expectRevert(ITrustedIssuersRegistry.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), abi.encodeCall(TrustedIssuersRegistry.initialize, (admin, address(0))));
    }

    function test_Upgrade_RevertsWhenCallerIsNotUpgrader() public {
        TrustedIssuersRegistry newImplementation = new TrustedIssuersRegistry();
        vm.prank(other);
        vm.expectRevert();
        trustedIssuersRegistry.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_Upgrade_SucceedsWhenCallerHasUpgraderRole() public {
        TrustedIssuersRegistry newImplementation = new TrustedIssuersRegistry();
        vm.prank(admin);
        trustedIssuersRegistry.upgradeToAndCall(address(newImplementation), bytes(""));
    }
}
