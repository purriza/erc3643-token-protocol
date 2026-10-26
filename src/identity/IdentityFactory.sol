// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IIdentityFactory} from "../interfaces/IIdentityFactory.sol";
import {Identity} from "./Identity.sol";

/**
 * @title IdentityFactory
 * @notice Deploys one minimal Identity anchor per user
 */
contract IdentityFactory is IIdentityFactory, AccessControlUpgradeable, UUPSUpgradeable {
    
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to execute admin operations (create identities)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role allowed to upgrade the proxy
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping between user id hashes and their associated identity addresses
    mapping(bytes32 userIdHash => address identity) public identityByUserIdHash;

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

    /// @inheritdoc IIdentityFactory
    function initialize(address admin, address complianceAdmin) external initializer {
        if (admin == address(0) || complianceAdmin == address(0)) revert ZeroAddress();

        __AccessControl_init();

        // Grant roles to the admin and compliance admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, complianceAdmin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IIdentityFactory
    function createIdentity(bytes32 userIdHash, address identityAdmin)
        external
        onlyRole(ADMIN_ROLE)
        returns (address identity)
    {
        // Check if the identity admin is valid
        if (identityAdmin == address(0)) revert ZeroAddress();
        // Check if the user id hash is valid
        if (userIdHash == bytes32(0)) revert InvalidUserIdHash();
        // Check if the identity already exists
        if (identityByUserIdHash[userIdHash] != address(0)) revert IdentityAlreadyExists(userIdHash);

        // Deploy new identity
        identity = address(new Identity(identityAdmin, userIdHash));

        // Store identity address
        identityByUserIdHash[userIdHash] = identity;

        emit IdentityCreated(identity, userIdHash);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE) {
        (newImplementation);
    }
}
