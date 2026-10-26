// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {TestSetup} from "../../TestSetup.t.sol";

import {IIdentityRegistry} from "../../../src/interfaces/IIdentityRegistry.sol";
import {IdentityRegistry} from "../../../src/identity/IdentityRegistry.sol";
import {IdentityFactory} from "../../../src/identity/IdentityFactory.sol";
import {ClaimTopicsRegistry} from "../../../src/claims/ClaimTopicsRegistry.sol";
import {ClaimsRegistry} from "../../../src/claims/ClaimsRegistry.sol";
import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";

/*//////////////////////////////////////////////////////////////
                ISVERIFIED WITH REQUIRED CLAIMS
//////////////////////////////////////////////////////////////*/

contract IdentityRegistryVerificationTest is TestSetup {

    IdentityFactory internal identityFactory;
    ClaimTopicsRegistry internal topicsRegistry;
    ClaimsRegistry internal claimsRegistry;
    TopicCatalog internal topicCatalog;

    uint256 internal constant TOPIC_KYC = 1;
    uint256 internal constant TOPIC_AML = 2;

    function setUp() public override {
        super.setUp();

        (
            ,
            ,
            ,
            address identityFactoryAddr,
            address claimsRegistryAddr,
            address topicsRegistryAddr,
            ,
            ,
            ,
            
        ) = tokenFactory.emissions(DEFAULT_EMISSION_ID);

        identityFactory = IdentityFactory(identityFactoryAddr);
        claimsRegistry = ClaimsRegistry(claimsRegistryAddr);
        topicsRegistry = ClaimTopicsRegistry(topicsRegistryAddr);
        topicCatalog = TopicCatalog(tokenFactory.topicCatalog());

        vm.startPrank(admin);
        topicCatalog.setTopic(TOPIC_KYC, "KYC", "Know your customer", true);
        topicCatalog.setTopic(TOPIC_AML, "AML", "Anti money laundering", true);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        BASELINE (NO REQUIRED TOPICS)
    //////////////////////////////////////////////////////////////*/

    function test_IsVerified_FalseWhenNoIdentityBound() public view {
        assertFalse(emissionRegistry.isVerified(user1));
    }

    function test_IsVerified_TrueWhenIdentityBoundAndNoTopicsRequired() public {
        vm.prank(admin);
        emissionRegistry.setIdentity(user1, address(0x1234));
        assertTrue(emissionRegistry.isVerified(user1));
    }

    /*//////////////////////////////////////////////////////////////
                        WITH REQUIRED TOPICS
    //////////////////////////////////////////////////////////////*/

    function test_IsVerified_FalseWhenRequiredTopicButMissingClaim() public {
        vm.startPrank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);

        address id1 = identityFactory.createIdentity(keccak256("u1"), user1);
        emissionRegistry.setIdentity(user1, id1);
        vm.stopPrank();

        assertFalse(emissionRegistry.isVerified(user1));
    }

    function test_IsVerified_TrueWhenAllRequiredClaimsActive() public {
        vm.startPrank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);
        topicsRegistry.addTopic(TOPIC_AML);

        address id1 = identityFactory.createIdentity(keccak256("u1-all"), user1);
        emissionRegistry.setIdentity(user1, id1);
        claimsRegistry.setClaim(id1, TOPIC_KYC, keccak256("kyc"), uint64(block.timestamp + 1 days));
        claimsRegistry.setClaim(id1, TOPIC_AML, keccak256("aml"), uint64(block.timestamp + 1 days));
        vm.stopPrank();

        assertTrue(emissionRegistry.isVerified(user1));
    }

    function test_IsVerified_FalseWhenOnlyPartialClaims() public {
        vm.startPrank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);
        topicsRegistry.addTopic(TOPIC_AML);

        address id1 = identityFactory.createIdentity(keccak256("u1-partial"), user1);
        emissionRegistry.setIdentity(user1, id1);
        claimsRegistry.setClaim(id1, TOPIC_KYC, keccak256("kyc"), uint64(block.timestamp + 1 days));
        // AML missing on purpose
        vm.stopPrank();

        assertFalse(emissionRegistry.isVerified(user1));
    }

    function test_IsVerified_FalseWhenClaimRevoked() public {
        vm.startPrank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);

        address id1 = identityFactory.createIdentity(keccak256("u1-rev"), user1);
        emissionRegistry.setIdentity(user1, id1);
        claimsRegistry.setClaim(id1, TOPIC_KYC, keccak256("kyc"), uint64(block.timestamp + 1 days));
        vm.stopPrank();

        assertTrue(emissionRegistry.isVerified(user1));

        vm.prank(admin);
        claimsRegistry.revokeClaim(id1, TOPIC_KYC);

        assertFalse(emissionRegistry.isVerified(user1));
    }

    function test_IsVerified_FalseWhenClaimExpired() public {
        vm.startPrank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);

        address id1 = identityFactory.createIdentity(keccak256("u1-exp"), user1);
        emissionRegistry.setIdentity(user1, id1);
        claimsRegistry.setClaim(id1, TOPIC_KYC, keccak256("kyc"), uint64(block.timestamp + 10));
        vm.stopPrank();

        assertTrue(emissionRegistry.isVerified(user1));

        vm.warp(block.timestamp + 11);
        assertFalse(emissionRegistry.isVerified(user1));
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    function test_SetClaimTopicsRegistry_UpdatesAddress() public {
        address newRegistry = address(0xBEEF);

        vm.prank(admin);
        emissionRegistry.setClaimTopicsRegistry(newRegistry);

        assertEq(address(emissionRegistry.claimTopicsRegistry()), newRegistry);
    }

    function test_SetClaimTopicsRegistry_RevertsWhenNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        emissionRegistry.setClaimTopicsRegistry(address(0xBEEF));
    }

    function test_SetClaimTopicsRegistry_RevertsWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        emissionRegistry.setClaimTopicsRegistry(address(0));
    }

    function test_SetClaimsRegistry_UpdatesAddress() public {
        address newRegistry = address(0xCAFE);

        vm.prank(admin);
        emissionRegistry.setClaimsRegistry(newRegistry);

        assertEq(address(emissionRegistry.claimsRegistry()), newRegistry);
    }

    function test_SetClaimsRegistry_RevertsWhenNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        emissionRegistry.setClaimsRegistry(address(0xCAFE));
    }

    function test_SetClaimsRegistry_RevertsWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        emissionRegistry.setClaimsRegistry(address(0));
    }

}
