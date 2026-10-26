// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

/**
 * @title IIdentity
 * @notice Interface for the minimal per-user identity anchor
 */
interface IIdentity {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the identity admin is transferred
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when caller is not the identity admin
    error NotAdmin();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the admin controlling this identity
     */
    function admin() external view returns (address);

    /**
     * @notice Returns the hash linking this identity to an off-chain user id
     */
    function userIdHash() external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfers identity admin to a new address
     * @dev Only callable by current admin
     * @param newAdmin New admin address
     */
    function transferAdmin(address newAdmin) external;
}

