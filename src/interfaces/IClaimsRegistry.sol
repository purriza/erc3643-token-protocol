// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

/**
 * @title IClaimsRegistry
 * @notice Interface for the registry of claims
 */
interface IClaimsRegistry {


    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct describing a claim   
    /// @param issuer Address of the issuer of the claim
    /// @param dataHash Hash of the claim data
    /// @param validTo Validity of the claim
    /// @param revoked Whether the claim has been revoked
    struct Claim {
        address issuer;
        bytes32 dataHash;
        uint64 validTo;
        bool revoked;
    }
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a claim is set
    /// @param identity Address of the identity
    /// @param topic Topic of the claim
    /// @param issuer Address of the issuer of the claim
    /// @param dataHash Hash of the claim data
    /// @param validTo Validity of the claim
    event ClaimSet(address indexed identity, uint256 indexed topic, address indexed issuer, bytes32 dataHash, uint64 validTo);

    /// @notice Emitted when a claim is revoked
    /// @param identity Address of the identity
    /// @param topic Topic of the claim
    event ClaimRevoked(address indexed identity, uint256 indexed topic);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when providing an invalid topic
    error InvalidTopic(uint256 topic);

    /// @notice Thrown when providing an invalid validity
    error InvalidValidity();

    /// @notice Thrown when providing an invalid data hash
    error InvalidDataHash();

    /// @notice Thrown when the issuer is not trusted
    error IssuerNotTrusted(address issuer);

    /// @notice Thrown when a topic is not active in the global topic catalog
    error TopicNotInCatalog(uint256 topic);

    /// @notice Thrown when a claim is not found
    error ClaimNotFound(address identity, uint256 topic);

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the ClaimsRegistry contract
     * @param admin Address that will receive the DEFAULT_ADMIN_ROLE, ADMIN_ROLE and UPGRADER_ROLE
     * @param complianceAdmin Address that will also receive the ADMIN_ROLE
     * @param trustedIssuersRegistry Address of the TrustedIssuersRegistry contract
     * @param topicCatalog Address of the global TopicCatalog contract
     */
    function initialize(address admin, address complianceAdmin, address trustedIssuersRegistry, address topicCatalog)
        external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a claim
     * @param identity Address of the identity
     * @param topic Topic of the claim
     * @param dataHash Data hash of the claim
     * @param validTo Validity of the claim
     */
    function setClaim(address identity, uint256 topic, bytes32 dataHash, uint64 validTo) external;

    /**
     * @notice Revokes a claim
     * @param identity Address of the identity
     * @param topic Topic of the claim
     */
    function revokeClaim(address identity, uint256 topic) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether a claim is active
     * @param identity Address of the identity
     * @param topic Topic of the claim
     * @return hasActiveClaim Whether the claim is active
     */
    function hasActiveClaim(address identity, uint256 topic) external view returns (bool hasActiveClaim);
}
