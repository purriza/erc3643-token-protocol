// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TrustedIssuersRegistry} from "../../../src/claims/TrustedIssuersRegistry.sol";
import {ClaimsRegistry} from "../../../src/claims/ClaimsRegistry.sol";
import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";
import {IClaimsRegistry} from "../../../src/interfaces/IClaimsRegistry.sol";

contract ClaimsRegistryTest is Test {
    address internal admin = makeAddr("admin");
    address internal complianceAdmin = makeAddr("complianceAdmin");
    address internal other = makeAddr("other");
    address internal identity = makeAddr("identity");
    uint256 internal constant TOPIC = 1;

    TrustedIssuersRegistry internal issuersRegistry;
    ClaimsRegistry internal claimsRegistry;
    TopicCatalog internal topicCatalog;

    function setUp() public {
        TrustedIssuersRegistry issuersImpl = new TrustedIssuersRegistry();
        bytes memory issuersInitData = abi.encodeCall(TrustedIssuersRegistry.initialize, (admin, complianceAdmin));
        ERC1967Proxy issuersProxy = new ERC1967Proxy(address(issuersImpl), issuersInitData);
        issuersRegistry = TrustedIssuersRegistry(address(issuersProxy));

        TopicCatalog catalogImpl = new TopicCatalog();
        bytes memory catalogInitData = abi.encodeCall(TopicCatalog.initialize, (admin));
        ERC1967Proxy catalogProxy = new ERC1967Proxy(address(catalogImpl), catalogInitData);
        topicCatalog = TopicCatalog(address(catalogProxy));

        vm.prank(admin);
        topicCatalog.setTopic(TOPIC, "KYC", "Know your customer", true);

        ClaimsRegistry claimsImpl = new ClaimsRegistry();
        bytes memory claimsInitData = abi.encodeCall(
            ClaimsRegistry.initialize, (admin, complianceAdmin, address(issuersRegistry), address(topicCatalog))
        );
        ERC1967Proxy claimsProxy = new ERC1967Proxy(address(claimsImpl), claimsInitData);
        claimsRegistry = ClaimsRegistry(address(claimsProxy));
    }

    function test_SetClaim_SuccessAndHasActiveClaimTrue() public {
        uint64 validTo = uint64(block.timestamp + 1 days);

        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(admin, true);

        vm.prank(admin);
        claimsRegistry.setClaim(identity, TOPIC, keccak256("claim-1"), validTo);

        assertTrue(claimsRegistry.hasActiveClaim(identity, TOPIC));
    }

    function test_SetClaim_RevertsWhenNotAdminRole() public {
        vm.prank(other);
        vm.expectRevert();
        claimsRegistry.setClaim(identity, TOPIC, keccak256("claim-2"), uint64(block.timestamp + 1 days));
    }

    function test_SetClaim_RevertsWhenIssuerNotTrusted() public {
        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(admin, false);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IClaimsRegistry.IssuerNotTrusted.selector, admin));
        claimsRegistry.setClaim(identity, TOPIC, keccak256("claim-3"), uint64(block.timestamp + 1 days));
    }

    function test_SetClaim_RevertsWhenTopicNotInCatalog() public {
        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(admin, true);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IClaimsRegistry.TopicNotInCatalog.selector, 9999));
        claimsRegistry.setClaim(identity, 9999, keccak256("claim-topic-missing"), uint64(block.timestamp + 1 days));
    }

    function test_SetClaim_RevertsWhenTopicDeactivatedInCatalog() public {
        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(admin, true);

        vm.prank(admin);
        topicCatalog.setTopicActive(TOPIC, false);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IClaimsRegistry.TopicNotInCatalog.selector, TOPIC));
        claimsRegistry.setClaim(identity, TOPIC, keccak256("claim-topic-inactive"), uint64(block.timestamp + 1 days));
    }

    function test_Initialize_RevertsWhenTopicCatalogIsZeroAddress() public {
        ClaimsRegistry claimsImpl = new ClaimsRegistry();
        bytes memory claimsInitData =
            abi.encodeCall(ClaimsRegistry.initialize, (admin, complianceAdmin, address(issuersRegistry), address(0)));

        vm.expectRevert(IClaimsRegistry.ZeroAddress.selector);
        new ERC1967Proxy(address(claimsImpl), claimsInitData);
    }

    function test_SetClaim_RevertsOnInvalidInputs() public {
        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(admin, true);

        vm.startPrank(admin);

        vm.expectRevert(IClaimsRegistry.ZeroAddress.selector);
        claimsRegistry.setClaim(address(0), TOPIC, keccak256("claim-4"), uint64(block.timestamp + 1 days));

        vm.expectRevert(abi.encodeWithSelector(IClaimsRegistry.InvalidTopic.selector, 0));
        claimsRegistry.setClaim(identity, 0, keccak256("claim-5"), uint64(block.timestamp + 1 days));

        vm.expectRevert(IClaimsRegistry.InvalidDataHash.selector);
        claimsRegistry.setClaim(identity, TOPIC, bytes32(0), uint64(block.timestamp + 1 days));

        vm.expectRevert(IClaimsRegistry.InvalidValidity.selector);
        claimsRegistry.setClaim(identity, TOPIC, keccak256("claim-6"), uint64(block.timestamp));

        vm.stopPrank();
    }

    function test_HasActiveClaim_FalseWhenExpired() public {
        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(admin, true);

        vm.prank(admin);
        claimsRegistry.setClaim(identity, TOPIC, keccak256("claim-7"), uint64(block.timestamp + 10));

        vm.warp(block.timestamp + 11);
        assertFalse(claimsRegistry.hasActiveClaim(identity, TOPIC));
    }

    function test_HasActiveClaim_FalseWhenIssuerBecomesUntrusted() public {
        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(admin, true);

        vm.prank(admin);
        claimsRegistry.setClaim(identity, TOPIC, keccak256("claim-8"), uint64(block.timestamp + 1 days));
        assertTrue(claimsRegistry.hasActiveClaim(identity, TOPIC));

        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(admin, false);
        assertFalse(claimsRegistry.hasActiveClaim(identity, TOPIC));
    }

    function test_HasActiveClaim_FalseWhenInvalidIdentityOrTopic() public view {
        assertFalse(claimsRegistry.hasActiveClaim(address(0), TOPIC));
        assertFalse(claimsRegistry.hasActiveClaim(identity, 0));
    }

    function test_RevokeClaim_MakesClaimInactive() public {
        vm.prank(admin);
        issuersRegistry.setTrustedIssuer(admin, true);

        vm.startPrank(admin);
        claimsRegistry.setClaim(identity, TOPIC, keccak256("claim-9"), uint64(block.timestamp + 1 days));
        claimsRegistry.revokeClaim(identity, TOPIC);
        vm.stopPrank();

        assertFalse(claimsRegistry.hasActiveClaim(identity, TOPIC));
    }

    function test_RevokeClaim_RevertsOnInvalidInputs() public {
        vm.startPrank(admin);
        vm.expectRevert(IClaimsRegistry.ZeroAddress.selector);
        claimsRegistry.revokeClaim(address(0), TOPIC);

        vm.expectRevert(abi.encodeWithSelector(IClaimsRegistry.InvalidTopic.selector, 0));
        claimsRegistry.revokeClaim(identity, 0);
        vm.stopPrank();
    }

    function test_RevokeClaim_RevertsWhenClaimNotFound() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IClaimsRegistry.ClaimNotFound.selector, identity, TOPIC));
        claimsRegistry.revokeClaim(identity, TOPIC);
    }
}

