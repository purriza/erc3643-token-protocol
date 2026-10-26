// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

/**
 * @title ITokenFactory
 * @notice Interface for the factory that deploys regulated Token3643 emissions
 */
interface ITokenFactory {
    
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct describing the core contracts of an emission
    struct Emission {
        address token;
        address registry;
        address compliance;
        address identityFactory;
        address claimsRegistry;
        address claimTopicsRegistry;
        address trustedIssuersRegistry;
        address claimComplianceModule;
        address walletFreezeComplianceModule;
        address treasury;
    }

    /// @notice Struct aggregating configuration parameters used when creating a new emission
    struct EmissionInput {
        string name;
        string symbol;
        uint256 maxSupply;
        address treasury;
        address admin;
        address complianceAdmin;
        address agent;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new emission is created
     * @param emissionId Unique identifier of the emission
     * @param token Address of the Token3643 instance
     * @param registry Address of the IdentityRegistry proxy
     * @param compliance Address of the ComplianceBase proxy
     * @param identityFactory Address of the IdentityFactory proxy
     * @param claimsRegistry Address of the ClaimsRegistry proxy
     * @param claimTopicsRegistry Address of the ClaimTopicsRegistry proxy
     * @param trustedIssuersRegistry Address of the TrustedIssuersRegistry proxy
     * @param claimComplianceModule Address of the ClaimComplianceModule instance
     * @param walletFreezeComplianceModule Address of the WalletFreezeComplianceModule instance
     * @param treasury Address of the emission treasury
     */
    event EmissionCreated(
        bytes32 indexed emissionId,
        address indexed token,
        address registry,
        address compliance,
        address identityFactory,
        address claimsRegistry,
        address claimTopicsRegistry,
        address trustedIssuersRegistry,
        address claimComplianceModule,
        address walletFreezeComplianceModule,
        address treasury
    );

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to create an emission whose identifier is already in use
    error EmissionAlreadyExists(bytes32 emissionId);

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

     /// @notice Thrown when attempting to create an emission with an invalid identifier
     error InvalidEmissionId();

     /// @notice Thrown when attempting to create an emission with an invalid max supply
     error InvalidMaxSupply();

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the TokenFactory contract
     * @param admin Address that will receive DEFAULT_ADMIN_ROLE, ADMIN_ROLE and UPGRADER_ROLE
     * @param emissionDeployerManager Address of the EmissionDeployerManager helper contract
     * @param topicCatalog Address of the global TopicCatalog proxy
     */
    function initialize(address admin, address emissionDeployerManager, address topicCatalog) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new regulated emission
     * @dev Deploys UUPS proxies for IdentityRegistry and ComplianceBase
     *      and a Token3643 instance per emission. Callable only by accounts with ADMIN_ROLE.
     * @param emissionId Unique identifier for the emission
     * @param name Name of the Token3643
     * @param symbol Symbol of the Token3643
     * @param maxSupply Max supply minted to treasury in constructor
     * @param treasury Address of the emission treasury
     * @param admin Address that will receive DEFAULT_ADMIN_ROLE (and emission-specific roles) on the new contracts
     * @param complianceAdmin Address that will receive COMPLIANCE_ADMIN_ROLE
     * @param agent Address that will receive AGENT_ROLE on the token
     * @return token Address of the deployed Token3643
     * @return registry Address of the deployed IdentityRegistry proxy
     * @return compliance Address of the deployed ComplianceBase proxy
     */
    function createEmission(
        bytes32 emissionId,
        string calldata name,
        string calldata symbol,
        uint256 maxSupply,
        address treasury,
        address admin,
        address complianceAdmin,
        address agent
    ) external returns (address token, address registry, address compliance);

    /**
     * @notice Updates the EmissionDeployerManager address used for new deployments
     * @dev Callable only by accounts with ADMIN_ROLE.
     * @param newEmissionDeployerManager Address of the new EmissionDeployerManager contract
     */
    function setEmissionDeployerManager(address newEmissionDeployerManager) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the stored information about an emission
     * @param emissionId Identifier of the emission
     * @return token Address of the Token3643 instance
     * @return registry Address of the IdentityRegistry proxy
     * @return compliance Address of the ComplianceBase proxy
     * @return identityFactory Address of the IdentityFactory proxy
     * @return claimsRegistry Address of the ClaimsRegistry proxy
     * @return claimTopicsRegistry Address of the ClaimTopicsRegistry proxy
     * @return trustedIssuersRegistry Address of the TrustedIssuersRegistry proxy
     * @return claimComplianceModule Address of the ClaimComplianceModule instance
     * @return walletFreezeComplianceModule Address of the WalletFreezeComplianceModule instance
     * @return treasury Address of the emission treasury
     */
    function emissions(bytes32 emissionId)
        external
        view
        returns (
            address token,
            address registry,
            address compliance,
            address identityFactory,
            address claimsRegistry,
            address claimTopicsRegistry,
            address trustedIssuersRegistry,
            address claimComplianceModule,
            address walletFreezeComplianceModule,
            address treasury
        );
}

