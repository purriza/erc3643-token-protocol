// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";
import {ITopicCatalog} from "../../../src/interfaces/ITopicCatalog.sol";

contract TopicCatalogTopicsTest is Test {
    address internal admin = makeAddr("admin");
    address internal other = makeAddr("other");

    TopicCatalog internal topicCatalog;

    function setUp() public {
        TopicCatalog impl = new TopicCatalog();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(TopicCatalog.initialize, (admin)));
        topicCatalog = TopicCatalog(address(proxy));
    }

    function test_SetTopic_RevertsWhenInvalidTopic() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ITopicCatalog.InvalidTopic.selector, 0));
        topicCatalog.setTopic(0, "KYC", "Know your customer", true);
    }

    function test_SetTopic_RevertsWhenCodeIsEmpty() public {
        vm.prank(admin);
        vm.expectRevert(ITopicCatalog.EmptyCode.selector);
        topicCatalog.setTopic(1, "", "No code", true);
    }

    function test_SetTopic_RevertsWhenTopicAlreadyExists() public {
        vm.startPrank(admin);
        topicCatalog.setTopic(1, "KYC", "Know your customer", true);
        vm.expectRevert(abi.encodeWithSelector(ITopicCatalog.TopicAlreadyExists.selector, 1));
        topicCatalog.setTopic(1, "KYC2", "Duplicate", true);
        vm.stopPrank();
    }

    function test_SetTopicActive_RevertsWhenTopicNotFound() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ITopicCatalog.TopicNotFound.selector, 999));
        topicCatalog.setTopicActive(999, true);
    }

    function test_SetTopicActive_UpdatesStatus() public {
        vm.prank(admin);
        topicCatalog.setTopic(7, "AML", "Anti money laundering", true);
        assertTrue(topicCatalog.isTopicActive(7));

        vm.prank(admin);
        topicCatalog.setTopicActive(7, false);
        assertFalse(topicCatalog.isTopicActive(7));
    }

    function test_IsTopicActive_ReturnsFalseWhenTopicDoesNotExist() public view {
        assertFalse(topicCatalog.isTopicActive(12345));
    }

    function test_SetTopic_RevertsWhenNotAdmin() public {
        vm.prank(other);
        vm.expectRevert();
        topicCatalog.setTopic(2, "ACC", "Accredited", true);
    }
}
