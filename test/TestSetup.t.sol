// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Token / ERC-3643 contracts (src)
import {TokenFactory} from "../src/token/TokenFactory.sol";
import {Token3643} from "../src/token/Token3643.sol";
import {ComplianceBase} from "../src/compliance/ComplianceBase.sol";
import {IdentityRegistry} from "../src/identity/IdentityRegistry.sol";
import {EmissionDeployerManager} from "../src/token/EmissionDeployerManager.sol";
import {TopicCatalog} from "../src/claims/TopicCatalog.sol";
import {TrustedIssuersRegistry} from "../src/claims/TrustedIssuersRegistry.sol";
import {ClaimsRegistry} from "../src/claims/ClaimsRegistry.sol";
import {IdentityFactory} from "../src/identity/IdentityFactory.sol";

/**
 * @title TestSetup
 * @notice Shared setup for tests.
 *         Deploys TokenFactory and creates a default emission (token, registry, compliance).
 */
contract TestSetup is Test {
    // TokenFactory (ERC-3643)
    TokenFactory public tokenFactoryImpl;
    TokenFactory public tokenFactory;
    ERC1967Proxy public tokenFactoryProxy;

    // Default emission created by TokenFactory (for token/registry/compliance tests)
    bytes32 public constant DEFAULT_EMISSION_ID = keccak256("default");
    uint256 public constant DEFAULT_INITIAL_SUPPLY = 1_000_000 ether;
    Token3643 public emissionToken;
    IdentityRegistry public emissionRegistry;
    ComplianceBase public emissionCompliance;

    // Users
    address public admin = makeAddr("admin");
    address public upgrader = makeAddr("upgrader");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public treasuryWallet = makeAddr("treasuryWallet");

    function setUp() public virtual {
        vm.startPrank(admin);
        tokenFactory = _deployTokenFactory();
        _createDefaultTokenEmission();
        vm.stopPrank();
    }

    function _deployTokenFactory() internal returns (TokenFactory) {
        tokenFactoryImpl = new TokenFactory();

        // Deploy TopicCatalog behind a proxy for tests (global)
        TopicCatalog topicCatalogImpl = new TopicCatalog();
        bytes memory topicCatalogData = abi.encodeCall(TopicCatalog.initialize, (admin));
        ERC1967Proxy topicCatalogProxy = new ERC1967Proxy(address(topicCatalogImpl), topicCatalogData);
        TopicCatalog topicCatalog = TopicCatalog(address(topicCatalogProxy));

        // Deploy global TrustedIssuersRegistry behind a proxy
        TrustedIssuersRegistry tirImpl = new TrustedIssuersRegistry();
        bytes memory tirData = abi.encodeCall(TrustedIssuersRegistry.initialize, (admin, admin));
        ERC1967Proxy tirProxy = new ERC1967Proxy(address(tirImpl), tirData);

        // Deploy global ClaimsRegistry behind a proxy
        ClaimsRegistry claimsImpl = new ClaimsRegistry();
        bytes memory claimsData =
            abi.encodeCall(ClaimsRegistry.initialize, (admin, admin, address(tirProxy), address(topicCatalog)));
        ERC1967Proxy claimsProxy = new ERC1967Proxy(address(claimsImpl), claimsData);

        // Deploy the EmissionDeployerManager helper wired to global contracts
        IdentityFactory idfImpl = new IdentityFactory();
        bytes memory idfData = abi.encodeCall(IdentityFactory.initialize, (admin, admin));
        ERC1967Proxy idfProxy = new ERC1967Proxy(address(idfImpl), idfData);

        EmissionDeployerManager manager =
            new EmissionDeployerManager(
                admin,
                address(topicCatalog),
                address(claimsProxy),
                address(tirProxy),
                address(idfProxy)
            );

        // Deploy TokenFactory proxy wired to the manager and topic catalog
        bytes memory tokenFactoryData = abi.encodeWithSelector(
            TokenFactory.initialize.selector,
            admin,
            address(manager),
            address(topicCatalog)
        );
        tokenFactoryProxy = new ERC1967Proxy(address(tokenFactoryImpl), tokenFactoryData);

        // Allow only the TokenFactory proxy to call deployEmissionStack
        manager.setFactory(address(tokenFactoryProxy));

        return TokenFactory(address(tokenFactoryProxy));
    }

    /// @notice Creates the default token emission (token, registry, compliance) for tests
    function _createDefaultTokenEmission() internal {
        (address token, address registry, address compliance) = tokenFactory.createEmission(
            DEFAULT_EMISSION_ID,
            "TestToken",
            "TT",
            DEFAULT_INITIAL_SUPPLY,
            treasuryWallet,
            admin,
            admin,
            admin
        );
        emissionToken = Token3643(token);
        emissionRegistry = IdentityRegistry(registry);
        emissionCompliance = ComplianceBase(compliance);

        // Wire token and default compliance modules as the emission admin
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            address claimModule,
            address freezeModule,
            /*treasury_*/
        ) = tokenFactory.emissions(DEFAULT_EMISSION_ID);

        emissionCompliance.setToken(address(emissionToken));

        if (claimModule != address(0)) {
            emissionCompliance.addModule(claimModule);
        }

        if (freezeModule != address(0)) {
            emissionCompliance.addModule(freezeModule);
        }

    }
}
