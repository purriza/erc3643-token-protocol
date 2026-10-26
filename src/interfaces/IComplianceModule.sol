// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

/**
 * @title IComplianceModule
 * @notice Interface for compliance modules that can be used to validate transfers
 */
interface IComplianceModule {
    
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether a transfer is allowed under this module
     * @param from Address sending tokens (may be address(0) for mints)
     * @param to Address receiving tokens (may be address(0) for burns)
     * @param amount Amount of tokens being transferred
     * @return allowed True if the transfer is allowed by this module
     */
    function canTransfer(address from, address to, uint256 amount) external view returns (bool allowed);

    /**
     * @notice Hook called after a transfer has been executed
     * @dev Implementations may revert to enforce fail-closed behavior
     * @param from Address that sent tokens (may be address(0) for mints)
     * @param to Address that received tokens (may be address(0) for burns)
     * @param amount Amount of tokens that were transferred
     */
    function transferred(address from, address to, uint256 amount) external;
}

