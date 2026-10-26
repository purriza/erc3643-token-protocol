// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";

import {ITokenFactory} from "../../../src/interfaces/ITokenFactory.sol";
import {IdentityRegistry} from "../../../src/identity/IdentityRegistry.sol";
import {ComplianceBase} from "../../../src/compliance/ComplianceBase.sol";
import {IdentityFactory} from "../../../src/identity/IdentityFactory.sol";
import {ClaimTopicsRegistry} from "../../../src/claims/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../../../src/claims/TrustedIssuersRegistry.sol";
import {ClaimsRegistry} from "../../../src/claims/ClaimsRegistry.sol";
import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";
import {WalletFreezeComplianceModule} from "../../../src/compliance/WalletFreezeComplianceModule.sol";

/*//////////////////////////////////////////////////////////////
                        CREATE EMISSION
//////////////////////////////////////////////////////////////*/

contract TokenFactoryCreateEmissionTest is TestSetup {

    /*//////////////////////////////////////////////////////////////
                        STATE CHANGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateEmission_EmitsEmissionCreated() public {
        bytes32 pid = keccak256("new-emission");
        vm.prank(admin);
        tokenFactory.createEmission(
            pid,
            "NewToken",
            "NT",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            admin
        );
        (address t,,,,,,,,,) = tokenFactory.emissions(pid);
        assertNotEq(t, address(0));
    }

    function test_CreateEmission_FactoryHasNoRolesOnRegistryAndCompliance() public {
        bytes32 pid = keccak256("handover-check");
        vm.prank(admin);
        (, address registryProxy, address complianceProxy) = tokenFactory.createEmission(
            pid,
            "HandoverToken",
            "HT",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            admin
        );
        IdentityRegistry reg = IdentityRegistry(registryProxy);
        ComplianceBase comp = ComplianceBase(complianceProxy);

        assertFalse(reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(reg.hasRole(reg.COMPLIANCE_ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(reg.hasRole(reg.UPGRADER_ROLE(), address(tokenFactory)));
        assertFalse(comp.hasRole(comp.DEFAULT_ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(comp.hasRole(comp.ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(comp.hasRole(comp.PAUSER_ROLE(), address(tokenFactory)));
        assertFalse(comp.hasRole(comp.UPGRADER_ROLE(), address(tokenFactory)));
    }

    function test_CreateEmission_HandoverAndBootstrapOnClaimsStack() public {
        bytes32 pid = keccak256("claims-stack-check");
        address emissionComplianceAdmin = user1;

        vm.prank(admin);
        tokenFactory.createEmission(
            pid,
            "ClaimsToken",
            "CT",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            emissionComplianceAdmin,
            admin
        );

        (
            ,
            ,
            ,
            address identityFactoryProxy,
            address claimsRegistryProxy,
            address topicsRegistryProxy,
            address issuersRegistryProxy,
            ,
            address freezeModuleAddr,
            address emissionTreasury
        ) = tokenFactory.emissions(pid);

        IdentityFactory identityFactory = IdentityFactory(identityFactoryProxy);
        ClaimsRegistry claimsRegistry = ClaimsRegistry(claimsRegistryProxy);
        ClaimTopicsRegistry topicsRegistry = ClaimTopicsRegistry(topicsRegistryProxy);
        TrustedIssuersRegistry issuersRegistry = TrustedIssuersRegistry(issuersRegistryProxy);
        WalletFreezeComplianceModule freezeModule = WalletFreezeComplianceModule(freezeModuleAddr);

        // Factory should keep no roles in the claims stack.
        assertFalse(identityFactory.hasRole(identityFactory.DEFAULT_ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(identityFactory.hasRole(identityFactory.ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(identityFactory.hasRole(identityFactory.UPGRADER_ROLE(), address(tokenFactory)));
        assertFalse(claimsRegistry.hasRole(claimsRegistry.DEFAULT_ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(claimsRegistry.hasRole(claimsRegistry.ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(claimsRegistry.hasRole(claimsRegistry.UPGRADER_ROLE(), address(tokenFactory)));
        assertFalse(topicsRegistry.hasRole(topicsRegistry.DEFAULT_ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(topicsRegistry.hasRole(topicsRegistry.ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(topicsRegistry.hasRole(topicsRegistry.UPGRADER_ROLE(), address(tokenFactory)));
        assertFalse(issuersRegistry.hasRole(issuersRegistry.DEFAULT_ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(issuersRegistry.hasRole(issuersRegistry.ADMIN_ROLE(), address(tokenFactory)));
        assertFalse(issuersRegistry.hasRole(issuersRegistry.UPGRADER_ROLE(), address(tokenFactory)));

        // Admin / compliance admin should have operational roles as configured.
        assertTrue(identityFactory.hasRole(identityFactory.ADMIN_ROLE(), admin));
        // IdentityFactory is global; only the global admin has ADMIN_ROLE by default.
        assertFalse(identityFactory.hasRole(identityFactory.ADMIN_ROLE(), emissionComplianceAdmin));
        // ClaimsRegistry is global; only global admin manages global claims.
        assertTrue(claimsRegistry.hasRole(claimsRegistry.ADMIN_ROLE(), admin));
        assertFalse(claimsRegistry.hasRole(claimsRegistry.ADMIN_ROLE(), emissionComplianceAdmin));
        assertTrue(topicsRegistry.hasRole(topicsRegistry.ADMIN_ROLE(), admin));
        assertTrue(topicsRegistry.hasRole(topicsRegistry.ADMIN_ROLE(), emissionComplianceAdmin));
        // TrustedIssuersRegistry is global; only global admin gestiona emisores de confianza globales.
        assertTrue(issuersRegistry.hasRole(issuersRegistry.ADMIN_ROLE(), admin));
        assertFalse(issuersRegistry.hasRole(issuersRegistry.ADMIN_ROLE(), emissionComplianceAdmin));
        assertTrue(freezeModule.hasRole(freezeModule.ADMIN_ROLE(), admin));
        assertTrue(freezeModule.hasRole(freezeModule.ADMIN_ROLE(), emissionComplianceAdmin));
        assertFalse(freezeModule.hasRole(freezeModule.ADMIN_ROLE(), address(tokenFactory)));
        assertNotEq(address(freezeModule), address(0));

        // En el modelo global, sólo admin es issuer confiable por defecto; el complianceAdmin de emision no lo es automáticamente.
        assertTrue(issuersRegistry.isTrustedIssuer(admin));
        assertFalse(issuersRegistry.isTrustedIssuer(emissionComplianceAdmin));
        assertEq(emissionTreasury, treasuryWallet);
    }

    function test_CreateEmission_ClaimTopicsRegistryIsIndependentPerEmission() public {
        bytes32 pid1 = keccak256("topics-emission-1");
        bytes32 pid2 = keccak256("topics-emission-2");

        vm.startPrank(admin);
        tokenFactory.createEmission(
            pid1,
            "TopicsToken1",
            "TP1",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            admin
        );
        tokenFactory.createEmission(
            pid2,
            "TopicsToken2",
            "TP2",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            admin
        );
        vm.stopPrank();

        (, , , , , address topicsRegistryProxy1, , , , ) = tokenFactory.emissions(pid1);
        (, , , , , address topicsRegistryProxy2, , , , ) = tokenFactory.emissions(pid2);

        ClaimTopicsRegistry topicsRegistry1 = ClaimTopicsRegistry(topicsRegistryProxy1);
        ClaimTopicsRegistry topicsRegistry2 = ClaimTopicsRegistry(topicsRegistryProxy2);
        address topicCatalogAddr = tokenFactory.topicCatalog();

        vm.prank(admin);
        TopicCatalog(topicCatalogAddr).setTopic(777, "TEST_TOPIC", "Test emission-scoped topic", true);

        vm.prank(admin);
        topicsRegistry1.addTopic(777);

        assertEq(topicsRegistry1.topicsCount(), 1);
        assertEq(topicsRegistry2.topicsCount(), 0);
        assertEq(topicsRegistry1.topics(0), 777);
    }

    /*//////////////////////////////////////////////////////////////
                            NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateEmission_RevertsForNonAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        tokenFactory.createEmission(
            keccak256("unauthorized"),
            "U",
            "U",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            admin
        );
    }

    function test_CreateEmission_RevertsWhenEmissionIdZero() public {
        vm.prank(admin);
        vm.expectRevert(ITokenFactory.InvalidEmissionId.selector);
        tokenFactory.createEmission(
            bytes32(0),
            "Zero",
            "Z",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            admin
        );
    }

    function test_CreateEmission_RevertsWhenMaxSupplyIsZero() public {
        vm.prank(admin);
        vm.expectRevert(ITokenFactory.InvalidMaxSupply.selector);
        tokenFactory.createEmission(
            keccak256("zero-max-supply"),
            "ZeroSupply",
            "ZS",
            0,
            treasuryWallet,
            admin,
            admin,
            admin
        );
    }

    function test_CreateEmission_RevertsWhenEmissionAlreadyExists() public {
        bytes32 pid = keccak256("duplicate-emission");

        vm.startPrank(admin);
        tokenFactory.createEmission(
            pid,
            "DupToken",
            "DUP",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            admin
        );

        vm.expectRevert(abi.encodeWithSelector(ITokenFactory.EmissionAlreadyExists.selector, pid));
        tokenFactory.createEmission(
            pid,
            "DupToken2",
            "DUP2",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            admin
        );
        vm.stopPrank();
    }

    function test_CreateEmission_RevertsWhenTreasuryIsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ITokenFactory.ZeroAddress.selector);
        tokenFactory.createEmission(
            keccak256("zero-treasury"),
            "ZT",
            "ZT",
            DEFAULT_INITIAL_SUPPLY,
            address(0),
            admin,
            admin,
            admin
        );
    }

    function test_CreateEmission_RevertsWhenAdminIsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ITokenFactory.ZeroAddress.selector);
        tokenFactory.createEmission(
            keccak256("zero-admin"),
            "ZA",
            "ZA",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            address(0),
            admin,
            admin
        );
    }

    function test_CreateEmission_RevertsWhenComplianceAdminIsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ITokenFactory.ZeroAddress.selector);
        tokenFactory.createEmission(
            keccak256("zero-compliance-admin"),
            "ZCA",
            "ZCA",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            address(0),
            admin
        );
    }

    function test_CreateEmission_RevertsWhenAgentIsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ITokenFactory.ZeroAddress.selector);
        tokenFactory.createEmission(
            keccak256("zero-agent"),
            "ZG",
            "ZG",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            address(0)
        );
    }
}
