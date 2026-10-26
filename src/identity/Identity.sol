// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IIdentity} from "../interfaces/IIdentity.sol";

/**
 * @title Identity
 * @notice Minimal per-user identity anchor 
 */
contract Identity is IIdentity {
    
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Admin controlling this identity
    address public admin;

    /// @notice One-way hash linking this identity to an off-chain user id
    bytes32 public userIdHash;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys a new Identity
     * @param admin_ Admin address controlling this identity
     * @param userIdHash_ One-way hash linking to off-chain user id (no PII)
     */
    constructor(address admin_, bytes32 userIdHash_) {
        if (admin_ == address(0)) revert ZeroAddress();

        admin = admin_;
        userIdHash = userIdHash_;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN / EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IIdentity
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();

        emit AdminTransferred(admin, newAdmin);

        admin = newAdmin;
    }
}

