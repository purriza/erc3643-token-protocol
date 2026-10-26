// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IComplianceModule} from "./IComplianceModule.sol";
import {IIdentityRegistry} from "./IIdentityRegistry.sol";
import {IClaimTopicsRegistry} from "./IClaimTopicsRegistry.sol";
import {IClaimsRegistry} from "./IClaimsRegistry.sol";

/**
 * @title IClaimComplianceModule
 * @notice Interface for claim-based compliance module instances.
 */
interface IClaimComplianceModule is IComplianceModule {

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the sender does not satisfy required claim topics (identity/claims).
    error ClaimModule_SenderRequirementsNotSatisfied(address wallet);

    /// @notice Thrown when the receiver does not satisfy required claim topics (identity/claims).
    error ClaimModule_ReceiverRequirementsNotSatisfied(address wallet);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the identity registry used for wallet->identity resolution.
     */
    function identityRegistry() external view returns (IIdentityRegistry);

    /**
     * @notice Returns the claim topics registry used for required topics.
     */
    function topicsRegistry() external view returns (IClaimTopicsRegistry);

    /**
     * @notice Returns the claims registry used for claim validation.
     */
    function claimsRegistry() external view returns (IClaimsRegistry);

    /**
     * @notice Returns the treasury address exempted from claim checks.
     */
    function treasury() external view returns (address);
}
