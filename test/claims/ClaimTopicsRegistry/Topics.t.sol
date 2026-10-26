// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ClaimTopicsRegistry} from "../../../src/claims/ClaimTopicsRegistry.sol";
import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";
import {IClaimTopicsRegistry} from "../../../src/interfaces/IClaimTopicsRegistry.sol";

contract ClaimTopicsRegistryTopicsTest is Test {
    address internal admin = makeAddr("admin");
    address internal complianceAdmin = makeAddr("complianceAdmin");
    address internal other = makeAddr("other");

    ClaimTopicsRegistry internal topicsRegistry;
    TopicCatalog internal topicCatalog;

    function setUp() public {
        TopicCatalog catalogImpl = new TopicCatalog();
        bytes memory catalogInitData = abi.encodeCall(TopicCatalog.initialize, (admin));
        ERC1967Proxy catalogProxy = new ERC1967Proxy(address(catalogImpl), catalogInitData);
        topicCatalog = TopicCatalog(address(catalogProxy));

        ClaimTopicsRegistry impl = new ClaimTopicsRegistry();
        bytes memory initData =
            abi.encodeCall(ClaimTopicsRegistry.initialize, (admin, complianceAdmin, address(topicCatalog)));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        topicsRegistry = ClaimTopicsRegistry(address(proxy));

        vm.startPrank(admin);
        topicCatalog.setTopic(1, "KYC", "Know your customer", true);
        topicCatalog.setTopic(7, "ACCREDITED", "Accredited investor", true);
        topicCatalog.setTopic(11, "AML", "Anti money laundering", true);
        topicCatalog.setTopic(12, "JURISDICTION", "Allowed jurisdiction", true);
        topicCatalog.setTopic(33, "PEP", "Politically exposed person", true);
        vm.stopPrank();
    }

    function test_AddTopic_Success() public {
        vm.prank(admin);
        topicsRegistry.addTopic(1);

        assertEq(topicsRegistry.topicsCount(), 1);
        assertEq(topicsRegistry.topics(0), 1);
    }

    function test_AddTopic_RevertsWhenNotAdmin() public {
        vm.prank(other);
        vm.expectRevert();
        topicsRegistry.addTopic(1);
    }

    function test_AddTopic_RevertsWhenInvalidTopic() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IClaimTopicsRegistry.InvalidTopic.selector, 0));
        topicsRegistry.addTopic(0);
    }

    function test_AddTopic_RevertsWhenAlreadyRequired() public {
        vm.startPrank(admin);
        topicsRegistry.addTopic(7);
        vm.expectRevert(abi.encodeWithSelector(IClaimTopicsRegistry.TopicAlreadyRequired.selector, 7));
        topicsRegistry.addTopic(7);
        vm.stopPrank();
    }

    function test_AddTopic_RevertsWhenNotInGlobalCatalog() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IClaimTopicsRegistry.TopicNotInCatalog.selector, 9999));
        topicsRegistry.addTopic(9999);
    }

    function test_RemoveTopic_Success() public {
        vm.startPrank(admin);
        topicsRegistry.addTopic(11);
        topicsRegistry.addTopic(12);
        topicsRegistry.removeTopic(11);
        vm.stopPrank();

        assertEq(topicsRegistry.topicsCount(), 1);
        assertEq(topicsRegistry.topics(0), 12);
    }

    function test_RemoveTopic_RevertsWhenTopicNotRequired() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IClaimTopicsRegistry.TopicNotRequired.selector, 99));
        topicsRegistry.removeTopic(99);
    }

    function test_RemoveTopic_RevertsWhenTopicNotRequiredAfterIteratingList() public {
        vm.startPrank(admin);
        topicsRegistry.addTopic(11);
        topicsRegistry.addTopic(12);
        vm.expectRevert(abi.encodeWithSelector(IClaimTopicsRegistry.TopicNotRequired.selector, 99));
        topicsRegistry.removeTopic(99);
        vm.stopPrank();
    }

    function test_RemoveTopic_RevertsWhenInvalidTopic() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IClaimTopicsRegistry.InvalidTopic.selector, 0));
        topicsRegistry.removeTopic(0);
    }

    function test_RemoveThenAddTopic_RepresentsSetMembership() public {
        vm.startPrank(admin);
        topicsRegistry.addTopic(33);
        topicsRegistry.removeTopic(33);
        topicsRegistry.addTopic(33);
        vm.stopPrank();

        assertEq(topicsRegistry.topicsCount(), 1);
        assertEq(topicsRegistry.topics(0), 33);
    }

    function test_AddTopic_RevertsWhenTopicIsDeactivatedInCatalog() public {
        vm.startPrank(admin);
        topicCatalog.setTopicActive(7, false);
        vm.expectRevert(abi.encodeWithSelector(IClaimTopicsRegistry.TopicNotInCatalog.selector, 7));
        topicsRegistry.addTopic(7);
        vm.stopPrank();
    }
}

