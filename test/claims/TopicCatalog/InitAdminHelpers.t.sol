// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";
import {ITopicCatalog} from "../../../src/interfaces/ITopicCatalog.sol";

contract TopicCatalogInitAdminHelpersTest is Test {
    address internal admin = makeAddr("admin");
    address internal other = makeAddr("other");

    TopicCatalog internal topicCatalog;

    function setUp() public {
        TopicCatalog impl = new TopicCatalog();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(TopicCatalog.initialize, (admin)));
        topicCatalog = TopicCatalog(address(proxy));
    }

    function test_Initialize_RevertsWhenAdminIsZeroAddress() public {
        TopicCatalog impl = new TopicCatalog();
        vm.expectRevert(ITopicCatalog.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), abi.encodeCall(TopicCatalog.initialize, (address(0))));
    }

    function test_Upgrade_RevertsWhenCallerIsNotUpgrader() public {
        TopicCatalog newImplementation = new TopicCatalog();
        vm.prank(other);
        vm.expectRevert();
        topicCatalog.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_Upgrade_SucceedsWhenCallerHasUpgraderRole() public {
        TopicCatalog newImplementation = new TopicCatalog();
        vm.prank(admin);
        topicCatalog.upgradeToAndCall(address(newImplementation), bytes(""));
    }
}
