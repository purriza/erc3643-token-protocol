// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IComplianceModule} from "../interfaces/IComplianceModule.sol";
import {IClaimComplianceModule} from "../interfaces/IClaimComplianceModule.sol";
import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {IClaimTopicsRegistry} from "../interfaces/IClaimTopicsRegistry.sol";
import {IClaimsRegistry} from "../interfaces/IClaimsRegistry.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ClaimComplianceModule
 * @notice Compliance module that enforces active claims for required topics.
 */
contract ClaimComplianceModule is IClaimComplianceModule, ERC165 {
    
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Identity registry used to resolve wallet -> identity address.
    IIdentityRegistry public immutable identityRegistry;

    /// @notice Emission registry of required claim topics.
    IClaimTopicsRegistry public immutable topicsRegistry;

    /// @notice Claims registry used to check active claims by identity/topic.
    IClaimsRegistry public immutable claimsRegistry;

    /// @notice Treasury address exempted from claim checks.
    address public immutable treasury;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a claim-based compliance module bound to one emission stack.
     * @param identityRegistry_ Identity registry instance of the emission.
     * @param topicsRegistry_ Claim topics registry instance of the emission.
     * @param claimsRegistry_ Claims registry instance of the emission.
     * @param treasury_ Treasury address exempted from claim checks.
     */
    constructor(
        IIdentityRegistry identityRegistry_,
        IClaimTopicsRegistry topicsRegistry_,
        IClaimsRegistry claimsRegistry_,
        address treasury_
    ) {
        identityRegistry = identityRegistry_;
        topicsRegistry = topicsRegistry_;
        claimsRegistry = claimsRegistry_;
        treasury = treasury_;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComplianceModule
    /// @dev Reverts with ClaimModule_SenderRequirementsNotSatisfied or ClaimModule_ReceiverRequirementsNotSatisfied instead of returning false.
    function canTransfer(address from, address to, uint256) external view returns (bool allowed) {
        uint256 requiredTopics = topicsRegistry.topicsCount();
        if (requiredTopics == 0) {
            return true;
        }

        if (from != address(0) && !_addressHasRequiredClaims(from, requiredTopics)) {
            revert ClaimModule_SenderRequirementsNotSatisfied(from);
        }
        if (to != address(0) && !_addressHasRequiredClaims(to, requiredTopics)) {
            revert ClaimModule_ReceiverRequirementsNotSatisfied(to);
        }

        return true;
    }

    /// @inheritdoc IComplianceModule
    function transferred(address from, address to, uint256 amount) external pure {
        // No-op by design. This module currently enforces only pre-transfer checks.
        (from, to, amount);
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IComplianceModule).interfaceId
            || interfaceId == type(IClaimComplianceModule).interfaceId
            || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether a wallet satisfies all required claim topics.
     * @dev Treasury is exempt. A wallet without identity is non-compliant.
     * @param user Wallet address to evaluate.
     * @param requiredTopics Number of required topics configured in topics registry.
     */
    function _addressHasRequiredClaims(address user, uint256 requiredTopics) internal view returns (bool) {
        if (user == treasury) {
            return true;
        }

        address identityAddr = identityRegistry.identityOf(user);
        if (identityAddr == address(0)) {
            return false;
        }

        for (uint256 i = 0; i < requiredTopics; i++) {
            if (!claimsRegistry.hasActiveClaim(identityAddr, topicsRegistry.topics(i))) {
                return false;
            }
        }

        return true;
    }
}

