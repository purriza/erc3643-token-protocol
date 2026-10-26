// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ITokenFactory} from "../interfaces/ITokenFactory.sol";
import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {IComplianceBase} from "../interfaces/IComplianceBase.sol";
import {IClaimTopicsRegistry} from "../interfaces/IClaimTopicsRegistry.sol";
import {IIdentityFactory} from "../interfaces/IIdentityFactory.sol";
import {IClaimsRegistry} from "../interfaces/IClaimsRegistry.sol";

import {Token3643} from "./Token3643.sol";
import {IdentityRegistry} from "../identity/IdentityRegistry.sol";
import {ComplianceBase} from "../compliance/ComplianceBase.sol";
import {ClaimTopicsRegistry} from "../claims/ClaimTopicsRegistry.sol";
import {ITrustedIssuersRegistry} from "../interfaces/ITrustedIssuersRegistry.sol";
import {ITopicCatalog} from "../interfaces/ITopicCatalog.sol";
import {ClaimComplianceModule} from "../compliance/ClaimComplianceModule.sol";
import {WalletFreezeComplianceModule} from "../compliance/WalletFreezeComplianceModule.sol";

/**
 * @title EmissionDeployerManager
 * @notice Stateless helper that deploys the full ERC-3643 emission stack for TokenFactory
 * @dev This contract is not upgradeable and may only be called by the TokenFactory proxy.
 */
contract EmissionDeployerManager {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a function restricted to the TokenFactory is called by another address
    error NotFactory();

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Admin address allowed to configure the manager
    address public immutable admin;

    /// @notice TokenFactory proxy that is allowed to call this deployer
    address public factory;

    /// @notice Implementation contract used for all IdentityRegistry proxies
    address public immutable identityRegistryImplementation;

    /// @notice Implementation contract used for all ComplianceBase proxies
    address public immutable complianceBaseImplementation;

    /// @notice Implementation contract used for all ClaimTopicsRegistry proxies
    address public immutable claimTopicsRegistryImplementation;

    /// @notice Global IdentityFactory shared by all emissions
    IIdentityFactory public immutable identityFactory;

    /// @notice Global TopicCatalog proxy shared by all emissions
    ITopicCatalog public immutable topicCatalog;

    /// @notice Global ClaimsRegistry shared by all emissions
    IClaimsRegistry public immutable claimsRegistry;

    /// @notice Global TrustedIssuersRegistry shared by all emissions
    ITrustedIssuersRegistry public immutable trustedIssuersRegistry;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin_ Address that will administer the global TopicCatalog and configure the factory
     * @param topicCatalog_ Address of the global TopicCatalog proxy shared by all emissions
     * @param claimsRegistry_ Address of the global ClaimsRegistry proxy shared by all emissions
     * @param trustedIssuersRegistry_ Address of the global TrustedIssuersRegistry proxy shared by all emissions
     * @param identityFactory_ Address of the global IdentityFactory proxy shared by all emissions
     */
    constructor(
        address admin_,
        address topicCatalog_,
        address claimsRegistry_,
        address trustedIssuersRegistry_,
        address identityFactory_
    ) {
        if (
            admin_ == address(0) || topicCatalog_ == address(0) || claimsRegistry_ == address(0)
                || trustedIssuersRegistry_ == address(0) || identityFactory_ == address(0)
        ) {
            revert ZeroAddress();
        }

        admin = admin_;
        topicCatalog = ITopicCatalog(topicCatalog_);
        claimsRegistry = IClaimsRegistry(claimsRegistry_);
        trustedIssuersRegistry = ITrustedIssuersRegistry(trustedIssuersRegistry_);
        identityFactory = IIdentityFactory(identityFactory_);

        identityRegistryImplementation = address(new IdentityRegistry());
        complianceBaseImplementation = address(new ComplianceBase());
        claimTopicsRegistryImplementation = address(new ClaimTopicsRegistry());
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert NotFactory();
        }
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert ZeroAddress(); // reuse for unauthorized admin? (kept minimal)
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the TokenFactory proxy allowed to call {deployEmissionStack}
    /// @dev Can only be set once by the admin
    function setFactory(address factory_) external onlyAdmin {
        if (factory_ == address(0) || factory != address(0)) {
            revert ZeroAddress();
        }
        factory = factory_;
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the full emission stack (registry, compliance, token, claims)
     * @param input Aggregated configuration parameters for the emission
     * @return deployment Struct with all deployed contract addresses
     */
    function deployEmissionStack(ITokenFactory.EmissionInput calldata input)
        external
        onlyFactory
        returns (ITokenFactory.Emission memory deployment)
    {
        // Use global IdentityFactory for all emissions
        deployment.identityFactory = address(identityFactory);

        // Use global TrustedIssuersRegistry
        deployment.trustedIssuersRegistry = address(trustedIssuersRegistry);

        // Deploy ClaimTopicsRegistry proxy first so it can be wired into IdentityRegistry
        deployment.claimTopicsRegistry = address(
            new ERC1967Proxy(
                claimTopicsRegistryImplementation,
                abi.encodeCall(
                    IClaimTopicsRegistry.initialize, (input.admin, input.complianceAdmin, address(topicCatalog))
                )
            )
        );

        // Use global ClaimsRegistry
        deployment.claimsRegistry = address(claimsRegistry);

        // Deploy IdentityRegistry proxy wired to the emission's ClaimTopicsRegistry and global ClaimsRegistry
        deployment.registry = address(
            new ERC1967Proxy(
                identityRegistryImplementation,
                abi.encodeCall(
                    IIdentityRegistry.initialize,
                    (
                        input.admin,
                        input.complianceAdmin,
                        deployment.claimTopicsRegistry,
                        deployment.claimsRegistry
                    )
                )
            )
        );

        // Deploy ComplianceBase proxy (admin + complianceAdmin)
        deployment.compliance = address(
            new ERC1967Proxy(
                complianceBaseImplementation,
                abi.encodeCall(IComplianceBase.initialize, (input.admin, input.complianceAdmin, input.treasury))
            )
        );

        // Deploy Token3643 and compliance modules
        deployment.token = address(
            new Token3643(
                input.name,
                input.symbol,
                deployment.registry,
                deployment.compliance,
                input.treasury,
                input.admin,
                input.complianceAdmin,
                input.agent,
                input.maxSupply
            )
        );

        (deployment.claimComplianceModule, deployment.walletFreezeComplianceModule) = _deployComplianceModules(
            input, deployment.registry, deployment.claimTopicsRegistry, deployment.claimsRegistry
        );

        deployment.treasury = input.treasury;
    }

    /**
     * @notice Deploys the default compliance modules for an emission
     * @param input Aggregated configuration parameters for the emission
     * @param registry Address of the IdentityRegistry proxy for the emission
     * @param topicsRegistry Address of the ClaimTopicsRegistry proxy for the emission
     * @param claimsRegistry_ Address of the global ClaimsRegistry proxy
     * @return claimModule Address of the deployed ClaimComplianceModule
     * @return freezeModule Address of the deployed WalletFreezeComplianceModule
     */
    function _deployComplianceModules(
        ITokenFactory.EmissionInput calldata input,
        address registry,
        address topicsRegistry,
        address claimsRegistry_
    ) internal returns (address claimModule, address freezeModule) {
        claimModule = address(
            new ClaimComplianceModule(
                IIdentityRegistry(registry),
                IClaimTopicsRegistry(topicsRegistry),
                IClaimsRegistry(claimsRegistry_),
                input.treasury
            )
        );

        freezeModule = address(
            new WalletFreezeComplianceModule(
                IIdentityRegistry(registry),
                input.treasury,
                input.admin,
                input.complianceAdmin
            )
        );
    }
}

