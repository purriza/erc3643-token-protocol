// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

/**
 * @title IIdentityFactory
 * @notice Interface for the factory that deploys minimal per-user identity anchors
 */
interface IIdentityFactory {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new identity is created
     * @param identity Address of the created identity
     * @param userIdHash Hash linking the identity to an off-chain user id
     */
    event IdentityCreated(address indexed identity, bytes32 indexed userIdHash);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when providing an invalid user id hash
    error InvalidUserIdHash();

    /// @notice Thrown when an identity already exists for the given user id hash
    error IdentityAlreadyExists(bytes32 userIdHash);

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the IdentityFactory contract
     * @param admin Address that will receive the DEFAULT_ADMIN_ROLE, ADMIN_ROLE and UPGRADER_ROLE
     * @param complianceAdmin Address that will also receive the ADMIN_ROLE
     */
    function initialize(address admin, address complianceAdmin) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new identity
     * @param userIdHash Hash linking the identity to an off-chain user id
     * @param identityAdmin Address that will control the new identity
     * @return identity Address of the created identity
     */
    function createIdentity(bytes32 userIdHash, address identityAdmin) external returns (address identity);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the identity address for a given user id hash
     * @param userIdHash Hash linking the identity to an off-chain user id
     * @return identity Address of the identity
     */
    function identityByUserIdHash(bytes32 userIdHash) external view returns (address identity);
}

