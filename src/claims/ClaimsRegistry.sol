// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IClaimsRegistry} from "../interfaces/IClaimsRegistry.sol";
import {ITrustedIssuersRegistry} from "../interfaces/ITrustedIssuersRegistry.sol";
import {ITopicCatalog} from "../interfaces/ITopicCatalog.sol";

/**
 * @title ClaimsRegistry
 * @notice Stores claims by identity and topic
 */
contract ClaimsRegistry is IClaimsRegistry, AccessControlUpgradeable, UUPSUpgradeable {
    
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to execute admin operations (manage claims)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role allowed to upgrade the proxy
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Registry of trusted issuers
    ITrustedIssuersRegistry public trustedIssuersRegistry;

    /// @notice Global topic catalog used to validate claim topics
    ITopicCatalog public topicCatalog;

    /// @notice Mapping of identities to their claims
    mapping(address identity => mapping(uint256 topic => Claim claim)) public claimsByIdentityTopic;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IClaimsRegistry
    function initialize(address admin, address complianceAdmin, address trustedIssuersRegistry_, address topicCatalog_)
        external
        initializer
    {
        if (admin == address(0) || complianceAdmin == address(0) || trustedIssuersRegistry_ == address(0)
            || topicCatalog_ == address(0))
        {
            revert ZeroAddress();
        }

        __AccessControl_init();

        trustedIssuersRegistry = ITrustedIssuersRegistry(trustedIssuersRegistry_);
        topicCatalog = ITopicCatalog(topicCatalog_);

        // Grant roles to the admin and compliance admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, complianceAdmin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IClaimsRegistry
    function setClaim(address identity, uint256 topic, bytes32 dataHash, uint64 validTo) external onlyRole(ADMIN_ROLE) {
        // Check if the identity is valid
        if (identity == address(0)) revert ZeroAddress();
        // Check if the topic is valid
        if (topic == 0) revert InvalidTopic(topic);
        // Check if the topic is active
        if (!topicCatalog.isTopicActive(topic)) revert TopicNotInCatalog(topic);
        // Check if the data hash is valid
        if (dataHash == bytes32(0)) revert InvalidDataHash();
        // Check if the validity is valid
        if (validTo <= block.timestamp) revert InvalidValidity();
        // Check if the issuer is trusted   
        if (!trustedIssuersRegistry.isTrustedIssuer(msg.sender)) revert IssuerNotTrusted(msg.sender);

        // Set the claim
        claimsByIdentityTopic[identity][topic] = Claim({issuer: msg.sender, dataHash: dataHash, validTo: validTo, revoked: false});

        emit ClaimSet(identity, topic, msg.sender, dataHash, validTo);
    }
    /// @inheritdoc IClaimsRegistry
    function revokeClaim(address identity, uint256 topic) external onlyRole(ADMIN_ROLE) {
        // Check if the identity is valid
        if (identity == address(0)) revert ZeroAddress();
        // Check if the topic is valid
        if (topic == 0) revert InvalidTopic(topic);
        // Check if the claim exists
        if (claimsByIdentityTopic[identity][topic].issuer == address(0)) revert ClaimNotFound(identity, topic);
        
        // Revoke the claim
        Claim storage claim = claimsByIdentityTopic[identity][topic];
        claim.revoked = true;

        emit ClaimRevoked(identity, topic);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IClaimsRegistry
    function hasActiveClaim(address identity, uint256 topic) external view returns (bool) {
        if (identity == address(0) || topic == 0) {
            return false;
        }

        Claim memory claim = claimsByIdentityTopic[identity][topic];
        if (claim.issuer == address(0) || claim.revoked || claim.validTo <= block.timestamp) {
            return false;
        }

        return trustedIssuersRegistry.isTrustedIssuer(claim.issuer);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE) {
        (newImplementation);
    }
}

