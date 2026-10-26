// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

/**
 * @title ITrustedIssuersRegistry
 * @notice Interface for the registry of trusted issuers of claims
 */
interface ITrustedIssuersRegistry {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an issuer trust status changes
    event TrustedIssuerSet(address indexed issuer, bool trusted);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the TrustedIssuersRegistry
     * @param admin Address that will receive DEFAULT_ADMIN_ROLE, ADMIN_ROLE and UPGRADER_ROLE
     * @param complianceAdmin Address that will also receive ADMIN_ROLE and be initially trusted
     */
    function initialize(address admin, address complianceAdmin) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets whether an issuer is trusted
     * @dev Only callable by ADMIN_ROLE
     * @param issuer Issuer address
     * @param trusted Whether the issuer is trusted
     */
    function setTrustedIssuer(address issuer, bool trusted) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether an issuer is trusted
     * @param issuer Issuer address
     */
    function isTrustedIssuer(address issuer) external view returns (bool);
}

