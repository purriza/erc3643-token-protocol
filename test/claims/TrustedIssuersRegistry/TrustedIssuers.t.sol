// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TrustedIssuersRegistry} from "../../../src/claims/TrustedIssuersRegistry.sol";
import {ITrustedIssuersRegistry} from "../../../src/interfaces/ITrustedIssuersRegistry.sol";

contract TrustedIssuersRegistryTest is Test {
    address internal admin = makeAddr("admin");
    address internal complianceAdmin = makeAddr("complianceAdmin");
    address internal issuer = makeAddr("issuer");
    address internal other = makeAddr("other");

    TrustedIssuersRegistry internal issuersRegistry;

    function setUp() public {
        TrustedIssuersRegistry impl = new TrustedIssuersRegistry();
        bytes memory initData = abi.encodeCall(TrustedIssuersRegistry.initialize, (admin, complianceAdmin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        issuersRegistry = TrustedIssuersRegistry(address(proxy));
    }

    function test_Initialize_SetsRoles() public view {
        assertTrue(issuersRegistry.hasRole(issuersRegistry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(issuersRegistry.hasRole(issuersRegistry.ADMIN_ROLE(), admin));
        assertTrue(issuersRegistry.hasRole(issuersRegistry.UPGRADER_ROLE(), admin));
    }

    function test_SetTrustedIssuer_Success() public {
        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(issuer, true);
        assertTrue(issuersRegistry.isTrustedIssuer(issuer));
    }

    function test_SetTrustedIssuer_CanUnset() public {
        vm.startPrank(admin);
        issuersRegistry.setTrustedIssuer(issuer, true);
        issuersRegistry.setTrustedIssuer(issuer, false);
        vm.stopPrank();

        assertFalse(issuersRegistry.isTrustedIssuer(issuer));
    }

    function test_SetTrustedIssuer_RevertsWhenNotAdmin() public {
        vm.prank(other);
        vm.expectRevert();
        issuersRegistry.setTrustedIssuer(issuer, true);
    }

    function test_SetTrustedIssuer_RevertsWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ITrustedIssuersRegistry.ZeroAddress.selector);
        issuersRegistry.setTrustedIssuer(address(0), true);
    }
}

