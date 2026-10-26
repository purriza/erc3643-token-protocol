// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ClaimTopicsRegistry} from "../../../src/claims/ClaimTopicsRegistry.sol";
import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";
import {IClaimTopicsRegistry} from "../../../src/interfaces/IClaimTopicsRegistry.sol";

contract ClaimTopicsRegistryInitAdminHelpersTest is Test {
    address internal admin = makeAddr("admin");
    address internal complianceAdmin = makeAddr("complianceAdmin");
    address internal other = makeAddr("other");

    ClaimTopicsRegistry internal topicsRegistry;
    TopicCatalog internal topicCatalog;

    function setUp() public {
        TopicCatalog catalogImpl = new TopicCatalog();
        ERC1967Proxy catalogProxy =
            new ERC1967Proxy(address(catalogImpl), abi.encodeCall(TopicCatalog.initialize, (admin)));
        topicCatalog = TopicCatalog(address(catalogProxy));

        ClaimTopicsRegistry impl = new ClaimTopicsRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeCall(ClaimTopicsRegistry.initialize, (admin, complianceAdmin, address(topicCatalog)))
        );
        topicsRegistry = ClaimTopicsRegistry(address(proxy));
    }

    function test_Initialize_RevertsWhenAdminIsZeroAddress() public {
        ClaimTopicsRegistry impl = new ClaimTopicsRegistry();
        vm.expectRevert(IClaimTopicsRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(ClaimTopicsRegistry.initialize, (address(0), complianceAdmin, address(topicCatalog)))
        );
    }

    function test_Initialize_RevertsWhenComplianceAdminIsZeroAddress() public {
        ClaimTopicsRegistry impl = new ClaimTopicsRegistry();
        vm.expectRevert(IClaimTopicsRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(ClaimTopicsRegistry.initialize, (admin, address(0), address(topicCatalog)))
        );
    }

    function test_Initialize_RevertsWhenTopicCatalogIsZeroAddress() public {
        ClaimTopicsRegistry impl = new ClaimTopicsRegistry();
        vm.expectRevert(IClaimTopicsRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl), abi.encodeCall(ClaimTopicsRegistry.initialize, (admin, complianceAdmin, address(0)))
        );
    }

    function test_Upgrade_RevertsWhenCallerIsNotUpgrader() public {
        ClaimTopicsRegistry newImplementation = new ClaimTopicsRegistry();
        vm.prank(other);
        vm.expectRevert();
        topicsRegistry.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_Upgrade_SucceedsWhenCallerHasUpgraderRole() public {
        ClaimTopicsRegistry newImplementation = new ClaimTopicsRegistry();
        vm.prank(admin);
        topicsRegistry.upgradeToAndCall(address(newImplementation), bytes(""));
    }
}
