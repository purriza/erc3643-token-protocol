// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IIdentityRegistry} from "./IIdentityRegistry.sol";
import {IComplianceBase} from "./IComplianceBase.sol";

/**
 * @title IToken3643
 * @notice Interface for a regulated ERC-20 style token with identity and compliance checks
 */
interface IToken3643 {

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when attempting to mint to an address different from the configured treasury
    error MintToNonTreasury(address to);

    /// @notice Thrown when the compliance engine rejects a transfer
    error ComplianceRejected();

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the identity registry used by this token
     * @dev Only callable by accounts with the ADMIN_ROLE
     * @param registry_ New registry address
     */
    function setRegistry(address registry_) external;

    /**
     * @notice Sets the compliance engine used by this token
     * @dev Only callable by accounts with the ADMIN_ROLE
     * @param compliance_ New compliance address
     */
    function setCompliance(address compliance_) external;

    /**
     * @notice Sets the treasury address
     * @dev Only callable by accounts with the ADMIN_ROLE
     * @param treasury_ New treasury address
     */
    function setTreasury(address treasury_) external;

    /**
     * @notice Performs a forced transfer between two addresses
     * @dev Only callable by accounts with the AGENT_ROLE; must still obey compliance rules
     * @param from Address from which tokens will be taken
     * @param to Address that will receive the tokens
     * @param amount Amount of tokens to transfer
     */
    function forcedTransfer(address from, address to, uint256 amount) external;

    /**
     * @notice Burns tokens from the caller balance
     * @dev Callable by any wallet; burns only from msg.sender
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the identity registry used by this token
     */
    function registry() external view returns (IIdentityRegistry);

    /**
     * @notice Returns the compliance engine used by this token
     */
    function compliance() external view returns (IComplianceBase);

    /**
     * @notice Returns the treasury address associated with this token
     */
    function treasury() external view returns (address);
}

