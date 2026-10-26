// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ITrustedIssuersRegistry} from "../interfaces/ITrustedIssuersRegistry.sol";

/**
 * @title TrustedIssuersRegistry
 * @notice Registry of issuers that are allowed to certify claims (e.g., KYC).
 */
contract TrustedIssuersRegistry is ITrustedIssuersRegistry, AccessControlUpgradeable, UUPSUpgradeable {

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to execute admin operations (manage trusted issuers)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role allowed to upgrade the proxy
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of issuers to their trusted status
    mapping(address issuer => bool trusted) public trustedIssuers;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustedIssuersRegistry
    function initialize(address admin, address complianceAdmin) external initializer {
        if (admin == address(0) || complianceAdmin == address(0)) revert ZeroAddress();

        __AccessControl_init();

        // Grant roles to the admin and compliance admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, complianceAdmin);
        _grantRole(UPGRADER_ROLE, admin);

        // Bootstrap compliance admin as trusted issuer
        trustedIssuers[complianceAdmin] = true;
        emit TrustedIssuerSet(complianceAdmin, true);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN / EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustedIssuersRegistry
    function setTrustedIssuer(address issuer, bool trusted) external onlyRole(ADMIN_ROLE) {
        if (issuer == address(0)) revert ZeroAddress();

        trustedIssuers[issuer] = trusted;

        emit TrustedIssuerSet(issuer, trusted);
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function isTrustedIssuer(address issuer) external view returns (bool) {
        return trustedIssuers[issuer];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE) {
        (newImplementation);
    }
}

