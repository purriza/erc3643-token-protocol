// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IComplianceModule} from "./IComplianceModule.sol";

/**
 * @title IComplianceBase
 * @notice Interface for the core compliance coordinator used by regulated tokens
 */
interface IComplianceBase {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new compliance module is added
     * @param module Address of the module that has been added
     */
    event ModuleAdded(address indexed module);

    /**
     * @notice Emitted when a compliance module is removed
     * @param module Address of the module that has been removed
     */
    event ModuleRemoved(address indexed module);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when attempting to add or use an invalid module address
    error InvalidModule();

    /// @notice Thrown when trying to add a module that is already configured
    error ModuleAlreadyAdded();

    /// @notice Thrown when trying to remove or reference a module that is not configured
    error ModuleNotFound();

    /// @notice Thrown when attempting to configure the token address more than once
    error TokenAlreadySet();

    /// @notice Thrown when a function restricted to the bound token is called by another address
    error NotTokenCaller();

    /// @notice Thrown when a transfer is checked while compliance is paused
    error CompliancePaused();

    /// @notice Thrown when a module returns false from canTransfer (module did not revert with a specific error)
    error ModuleRejected(address module);

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the ComplianceBase contract
     * @param admin Address that will receive the DEFAULT_ADMIN_ROLE
     * @param complianceAdmin Address that will receive the PAUSER_ROLE
     * @param treasury Address of the treasury that receives special flows
     */
    function initialize(address admin, address complianceAdmin, address treasury) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pauses all transfers governed by this compliance contract
     * @dev Only callable by accounts with the PAUSER_ROLE
     */
    function pause() external;

    /**
     * @notice Unpauses transfers governed by this compliance contract
     * @dev Only callable by accounts with the PAUSER_ROLE
     */
    function unpause() external;

    /**
     * @notice Sets the token contract allowed to call compliance hooks
     * @dev Only callable once by accounts with the ADMIN_ROLE
     * @param token Address of the token contract
     */
    function setToken(address token) external;

    /**
     * @notice Adds a new compliance module
     * @dev Only callable by accounts with the ADMIN_ROLE
     * @param module Address of the module to add
     */
    function addModule(address module) external;

    /**
     * @notice Removes an existing compliance module
     * @dev Only callable by accounts with the ADMIN_ROLE
     * @param module Address of the module to remove
     */
    function removeModule(address module) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether transfers governed by this contract are globally paused
     */
    function paused() external view returns (bool);

    /**
     * @notice Returns the token contract allowed to call compliance hooks
     */
    function token() external view returns (address);

    /**
     * @notice Returns the configured treasury address
     */
    function treasury() external view returns (address);

    /**
     * @notice Returns the list of registered compliance modules
     */
    function modules() external view returns (address[] memory);

    /**
     * @notice Returns whether a transfer is allowed by all configured modules
     * @param from Address sending tokens (may be address(0) for mints)
     * @param to Address receiving tokens (may be address(0) for burns)
     * @param amount Amount of tokens being transferred
     * @return allowed True if the transfer is allowed
     */
    function canTransfer(address from, address to, uint256 amount) external view returns (bool allowed);

    /**
     * @notice Hook to be called by the token after a transfer has been executed
     * @dev Implementations will forward the notification to all configured modules;
     *      any revert will bubble up and revert the entire transfer (fail-closed)
     * @param from Address that sent tokens (may be address(0) for mints)
     * @param to Address that received tokens (may be address(0) for burns)
     * @param amount Amount of tokens that were transferred
     */
    function transferred(address from, address to, uint256 amount) external;
}

