// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IClaimTopicsRegistry} from "./IClaimTopicsRegistry.sol";
import {IClaimsRegistry} from "./IClaimsRegistry.sol";

/**
 * @title IIdentityRegistry
 * @notice Interface for the on-chain identity registry used by regulated tokens
 */
interface IIdentityRegistry {
    
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted whenever the identity bound to a wallet is updated
     * @param wallet Address whose identity was updated
     * @param previousIdentity Identity address before the change
     * @param newIdentity Identity address after the change
     */
    event IdentitySet(address indexed wallet, address indexed previousIdentity, address indexed newIdentity);

    /**
     * @notice Emitted when the ClaimTopicsRegistry used for verification is updated
     * @param previousRegistry Previous registry address
     * @param newRegistry New registry address
     */
    event ClaimTopicsRegistrySet(address indexed previousRegistry, address indexed newRegistry);

    /**
     * @notice Emitted when the ClaimsRegistry used for verification is updated
     * @param previousRegistry Previous registry address
     * @param newRegistry New registry address
     */
    event ClaimsRegistrySet(address indexed previousRegistry, address indexed newRegistry);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when provided arrays do not have the same length
    error InvalidArrayLength();

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the IdentityRegistry contract
     * @param admin Address that will receive the DEFAULT_ADMIN_ROLE
     * @param complianceAdmin Address that will receive the COMPLIANCE_ADMIN_ROLE
     * @param claimTopicsRegistry Address of the ClaimTopicsRegistry used to fetch required topics
     * @param claimsRegistry Address of the ClaimsRegistry used to validate active claims
     */
    function initialize(
        address admin,
        address complianceAdmin,
        address claimTopicsRegistry,
        address claimsRegistry
    ) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the identity contract associated with a wallet
     * @dev Only callable by accounts with the COMPLIANCE_ADMIN_ROLE
     * @param wallet Wallet address to bind
     * @param identity Address of the Identity contract
     */
    function setIdentity(address wallet, address identity) external;

    /**
     * @notice Sets the identity contracts associated with multiple wallets in a single call
     * @dev Only callable by accounts with the COMPLIANCE_ADMIN_ROLE
     * @param wallets Wallet addresses to bind
     * @param identities Identity contract addresses (same order as wallets)
     */
    function setIdentities(address[] calldata wallets, address[] calldata identities) external;

    /**
     * @notice Updates the ClaimTopicsRegistry used to fetch required topics during verification
     * @dev Only callable by accounts with the DEFAULT_ADMIN_ROLE
     * @param claimTopicsRegistry New ClaimTopicsRegistry address (non-zero)
     */
    function setClaimTopicsRegistry(address claimTopicsRegistry) external;

    /**
     * @notice Updates the ClaimsRegistry used to validate active claims during verification
     * @dev Only callable by accounts with the DEFAULT_ADMIN_ROLE
     * @param claimsRegistry New ClaimsRegistry address (non-zero)
     */
    function setClaimsRegistry(address claimsRegistry) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether a user is considered verified
     * @dev A user is verified when it has:
     *      1) a non-zero identity bound, and
     *      2) an active claim for every topic required by the ClaimTopicsRegistry.
     *      When the ClaimTopicsRegistry has no required topics, step 2 is trivially satisfied.
     * @param user Address to query
     * @return isVerified True if the user is verified, false otherwise
     */
    function isVerified(address user) external view returns (bool isVerified);

    /**
     * @notice Returns the identity contract bound to a given wallet
     * @param wallet Wallet address to query
     * @return identity Address of the Identity contract (may be address(0) if none set)
     */
    function identityOf(address wallet) external view returns (address identity);

    /**
     * @notice Returns the ClaimTopicsRegistry used during verification
     */
    function claimTopicsRegistry() external view returns (IClaimTopicsRegistry);

    /**
     * @notice Returns the ClaimsRegistry used during verification
     */
    function claimsRegistry() external view returns (IClaimsRegistry);
}
