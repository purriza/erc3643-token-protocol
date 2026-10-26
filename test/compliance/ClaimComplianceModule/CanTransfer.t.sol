// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {TestSetup} from "../../TestSetup.t.sol";

import {IClaimComplianceModule} from "../../../src/interfaces/IClaimComplianceModule.sol";
import {ClaimComplianceModule} from "../../../src/compliance/ClaimComplianceModule.sol";
import {IdentityFactory} from "../../../src/identity/IdentityFactory.sol";
import {ClaimTopicsRegistry} from "../../../src/claims/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../../../src/claims/TrustedIssuersRegistry.sol";
import {ClaimsRegistry} from "../../../src/claims/ClaimsRegistry.sol";
import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";

contract ClaimComplianceModuleCanTransferTest is TestSetup {
    ClaimComplianceModule internal claimModule;
    IdentityFactory internal identityFactory;
    ClaimTopicsRegistry internal topicsRegistry;
    TrustedIssuersRegistry internal issuersRegistry;
    ClaimsRegistry internal claimsRegistry;
    TopicCatalog internal topicCatalog;

    uint256 internal constant TOPIC_KYC = 1;

    function setUp() public override {
        super.setUp();

        (
            ,
            ,
            ,
            address identityFactoryAddr,
            address claimsRegistryAddr,
            address topicsRegistryAddr,
            address issuersRegistryAddr,
            address claimModuleAddr,
            ,
            address emissionTreasury
        ) = tokenFactory.emissions(DEFAULT_EMISSION_ID);

        claimModule = ClaimComplianceModule(claimModuleAddr);
        identityFactory = IdentityFactory(identityFactoryAddr);
        claimsRegistry = ClaimsRegistry(claimsRegistryAddr);
        topicsRegistry = ClaimTopicsRegistry(topicsRegistryAddr);
        issuersRegistry = TrustedIssuersRegistry(issuersRegistryAddr);
        topicCatalog = TopicCatalog(tokenFactory.topicCatalog());
        assertEq(emissionTreasury, treasuryWallet);

        vm.prank(admin);
        topicCatalog.setTopic(TOPIC_KYC, "KYC", "Know your customer", true);
    }

    function test_CanTransfer_TrueWhenNoTopicsConfigured() public view {
        assertTrue(claimModule.canTransfer(user1, user2, 1 ether));
    }

    function test_CanTransfer_FalseWhenRequiredTopicButMissingIdentity() public {
        vm.prank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);

        vm.expectRevert(abi.encodeWithSelector(IClaimComplianceModule.ClaimModule_SenderRequirementsNotSatisfied.selector, user1));
        claimModule.canTransfer(user1, user2, 1 ether);
    }

    function test_CanTransfer_FalseWhenIdentitySetButMissingClaim() public {
        vm.prank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);

        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("u1"), user1);
        address id2 = identityFactory.createIdentity(keccak256("u2"), user2);
        emissionRegistry.setIdentity(user1, id1);
        emissionRegistry.setIdentity(user2, id2);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IClaimComplianceModule.ClaimModule_SenderRequirementsNotSatisfied.selector, user1));
        claimModule.canTransfer(user1, user2, 1 ether);
    }

    function test_CanTransfer_FalseWhenSenderCompliantButReceiverMissingIdentity() public {
        vm.prank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);

        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("u1-only"), user1);
        emissionRegistry.setIdentity(user1, id1);
        claimsRegistry.setClaim(id1, TOPIC_KYC, keccak256("claim-u1-only"), uint64(block.timestamp + 1 days));
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IClaimComplianceModule.ClaimModule_ReceiverRequirementsNotSatisfied.selector, user2));
        claimModule.canTransfer(user1, user2, 1 ether);
    }

    function test_CanTransfer_TrueWhenBothSidesHaveActiveClaimForRequiredTopic() public {
        vm.prank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);

        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("u1-ok"), user1);
        address id2 = identityFactory.createIdentity(keccak256("u2-ok"), user2);
        emissionRegistry.setIdentity(user1, id1);
        emissionRegistry.setIdentity(user2, id2);
        claimsRegistry.setClaim(id1, TOPIC_KYC, keccak256("claim-u1"), uint64(block.timestamp + 1 days));
        claimsRegistry.setClaim(id2, TOPIC_KYC, keccak256("claim-u2"), uint64(block.timestamp + 1 days));
        vm.stopPrank();

        assertTrue(claimModule.canTransfer(user1, user2, 1 ether));
    }

    function test_CanTransfer_TrueForTreasuryExemptionWhenCounterpartyIsCompliant() public {
        vm.prank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);

        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("u1-treasury"), user1);
        emissionRegistry.setIdentity(user1, id1);
        claimsRegistry.setClaim(id1, TOPIC_KYC, keccak256("claim-u1-treasury"), uint64(block.timestamp + 1 days));
        vm.stopPrank();

        // Treasury has no identity/claims but is exempt.
        assertTrue(claimModule.canTransfer(treasuryWallet, user1, 1 ether));
        assertTrue(claimModule.canTransfer(user1, treasuryWallet, 1 ether));
    }

    function test_CanTransfer_FalseWhenClaimExpires() public {
        vm.prank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);

        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("u1-exp"), user1);
        address id2 = identityFactory.createIdentity(keccak256("u2-exp"), user2);
        emissionRegistry.setIdentity(user1, id1);
        emissionRegistry.setIdentity(user2, id2);
        claimsRegistry.setClaim(id1, TOPIC_KYC, keccak256("claim-u1-exp"), uint64(block.timestamp + 10));
        claimsRegistry.setClaim(id2, TOPIC_KYC, keccak256("claim-u2-exp"), uint64(block.timestamp + 10));
        vm.stopPrank();

        assertTrue(claimModule.canTransfer(user1, user2, 1 ether));

        vm.warp(block.timestamp + 11);
        vm.expectRevert(abi.encodeWithSelector(IClaimComplianceModule.ClaimModule_SenderRequirementsNotSatisfied.selector, user1));
        claimModule.canTransfer(user1, user2, 1 ether);
    }

    function test_DefaultComplianceAdminIsTrustedIssuer() public view {
        assertTrue(issuersRegistry.isTrustedIssuer(admin));
    }
}

