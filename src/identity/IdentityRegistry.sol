// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {IClaimTopicsRegistry} from "../interfaces/IClaimTopicsRegistry.sol";
import {IClaimsRegistry} from "../interfaces/IClaimsRegistry.sol";

/**
 * @title IdentityRegistry
 * @notice Identity registry for regulated token holders
 */
contract IdentityRegistry is IIdentityRegistry, AccessControlUpgradeable, UUPSUpgradeable {
    
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to manage wallet-to-identity bindings
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");

    /// @notice Role allowed to upgrade the proxy
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Identity contract associated with each wallet 
    mapping(address wallet => address identity) public identityOf;

    /// @notice Registry of required claim topics checked during verification
    IClaimTopicsRegistry public claimTopicsRegistry;

    /// @notice Registry of claims checked during verification
    IClaimsRegistry public claimsRegistry;

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

    /// @inheritdoc IIdentityRegistry
    function initialize(
        address admin,
        address complianceAdmin,
        address claimTopicsRegistry_,
        address claimsRegistry_
    ) external initializer {
        if (
            admin == address(0) || complianceAdmin == address(0)
                || claimTopicsRegistry_ == address(0) || claimsRegistry_ == address(0)
        ) {
            revert ZeroAddress();
        }

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ADMIN_ROLE, complianceAdmin);
        _grantRole(UPGRADER_ROLE, admin);

        claimTopicsRegistry = IClaimTopicsRegistry(claimTopicsRegistry_);
        claimsRegistry = IClaimsRegistry(claimsRegistry_);

        emit ClaimTopicsRegistrySet(address(0), claimTopicsRegistry_);
        emit ClaimsRegistrySet(address(0), claimsRegistry_);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IIdentityRegistry
    function setIdentity(address wallet, address identity) external onlyRole(COMPLIANCE_ADMIN_ROLE) {
        if (wallet == address(0) || identity == address(0)) {
            revert ZeroAddress();
        }
        address previous = identityOf[wallet];
        identityOf[wallet] = identity;

        emit IdentitySet(wallet, previous, identity);
    }

    /// @inheritdoc IIdentityRegistry
    function setIdentities(address[] calldata wallets, address[] calldata identities)
        external
        onlyRole(COMPLIANCE_ADMIN_ROLE)
    {
        if (wallets.length != identities.length) {
            revert InvalidArrayLength();
        }

        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];
            address identity = identities[i];
            if (wallet == address(0) || identity == address(0)) {
                revert ZeroAddress();
            }

            address previous = identityOf[wallet];
            identityOf[wallet] = identity;

            emit IdentitySet(wallet, previous, identity);
        }
    }

    /// @inheritdoc IIdentityRegistry
    function setClaimTopicsRegistry(address claimTopicsRegistry_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (claimTopicsRegistry_ == address(0)) {
            revert ZeroAddress();
        }
        address previous = address(claimTopicsRegistry);
        claimTopicsRegistry = IClaimTopicsRegistry(claimTopicsRegistry_);

        emit ClaimTopicsRegistrySet(previous, claimTopicsRegistry_);
    }

    /// @inheritdoc IIdentityRegistry
    function setClaimsRegistry(address claimsRegistry_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (claimsRegistry_ == address(0)) {
            revert ZeroAddress();
        }
        address previous = address(claimsRegistry);
        claimsRegistry = IClaimsRegistry(claimsRegistry_);

        emit ClaimsRegistrySet(previous, claimsRegistry_);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IIdentityRegistry
    function isVerified(address user) external view returns (bool) {
        address identity = identityOf[user];
        if (identity == address(0)) {
            return false;
        }

        uint256 requiredTopics = claimTopicsRegistry.topicsCount();
        if (requiredTopics == 0) {
            return true;
        }

        for (uint256 i = 0; i < requiredTopics; i++) {
            if (!claimsRegistry.hasActiveClaim(identity, claimTopicsRegistry.topics(i))) {
                return false;
            }
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE) {
        (newImplementation);
    }
}
