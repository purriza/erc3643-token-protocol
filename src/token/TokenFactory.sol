// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ITokenFactory} from "../interfaces/ITokenFactory.sol";
import {EmissionDeployerManager} from "./EmissionDeployerManager.sol";

/**
 * @title TokenFactory
 * @notice Factory for deploying regulated Token3643 emissions
 */
contract TokenFactory is ITokenFactory, AccessControlUpgradeable, UUPSUpgradeable {
    
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to execute admin operations (create emissions)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role allowed to upgrade the proxy
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Emission stack deployer manager contract that deploys emission stacks
    address public emissionDeployerManager;

    /// @notice Global TopicCatalog proxy shared by all emissions used to validate claim topics
    address public topicCatalog;

    /// @notice Mapping between emission identifiers and deployed contracts
    mapping(bytes32 emissionId => Emission emission) public emissionsById;

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

    /// @inheritdoc ITokenFactory
    function initialize(address admin, address emissionDeployerManager_, address topicCatalog_) external initializer {
        if (admin == address(0) || emissionDeployerManager_ == address(0) || topicCatalog_ == address(0)) {
            revert ZeroAddress();
        }

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        emissionDeployerManager = emissionDeployerManager_;
        topicCatalog = topicCatalog_;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITokenFactory
    function createEmission(
        bytes32 emissionId,
        string calldata name,
        string calldata symbol,
        uint256 maxSupply,
        address treasury,
        address admin,
        address complianceAdmin,
        address agent
    )
        external
        onlyRole(ADMIN_ROLE)
        returns (address token, address registry, address compliance)
    {
        if (emissionId == bytes32(0)) {
            revert InvalidEmissionId();
        }
        if (maxSupply == 0) {
            revert InvalidMaxSupply();
        }

        if (treasury == address(0) || admin == address(0) || complianceAdmin == address(0) || agent == address(0)) {
            revert ZeroAddress();
        }

        EmissionInput memory input = EmissionInput({
            name: name,
            symbol: symbol,
            maxSupply: maxSupply,
            treasury: treasury,
            admin: admin,
            complianceAdmin: complianceAdmin,
            agent: agent
        });
        return _createEmission(emissionId, input);
    }

    /// @inheritdoc ITokenFactory
    function setEmissionDeployerManager(address newEmissionDeployerManager) external onlyRole(ADMIN_ROLE) {
        if (newEmissionDeployerManager == address(0)) {
            revert ZeroAddress();
        }
        emissionDeployerManager = newEmissionDeployerManager;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITokenFactory
    function emissions(bytes32 emissionId)
        external
        view
        returns (
            address token,
            address registry,
            address compliance,
            address identityFactory,
            address claimsRegistry,
            address claimTopicsRegistry,
            address trustedIssuersRegistry,
            address claimComplianceModule,
            address walletFreezeComplianceModule,
            address treasury
        )
    {
        Emission memory emission = emissionsById[emissionId];
        return (
            emission.token,
            emission.registry,
            emission.compliance,
            emission.identityFactory,
            emission.claimsRegistry,
            emission.claimTopicsRegistry,
            emission.trustedIssuersRegistry,
            emission.claimComplianceModule,
            emission.walletFreezeComplianceModule,
            emission.treasury
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal helper that deploys and wires the full emission stack
    /// @param emissionId Unique identifier of the emission to create
    /// @param input Aggregated configuration parameters for the emission
    /// @return token Address of the deployed Token3643 contract
    /// @return registry Address of the deployed IdentityRegistry proxy
    /// @return compliance Address of the deployed ComplianceBase proxy
    function _createEmission(bytes32 emissionId, EmissionInput memory input)
        internal
        returns (address token, address registry, address compliance)
    {
        _ensureEmissionDoesNotExist(emissionId);

        // Delegate heavy deployment logic to the dedicated helper contract
        Emission memory deployment = EmissionDeployerManager(emissionDeployerManager).deployEmissionStack(input);

        // Store emission information and emit event
        deployment.treasury = input.treasury;
        _storeEmission(emissionId, deployment);
        emit EmissionCreated(
            emissionId,
            deployment.token,
            deployment.registry,
            deployment.compliance,
            deployment.identityFactory,
            deployment.claimsRegistry,
            deployment.claimTopicsRegistry,
            deployment.trustedIssuersRegistry,
            deployment.claimComplianceModule,
            deployment.walletFreezeComplianceModule,
            deployment.treasury
        );

        return (deployment.token, deployment.registry, deployment.compliance);
    }

    /// @notice Stores all deployed emission contracts for a given emission id
    /// @param emissionId Emission identifier
    /// @param deployment Struct containing all deployed contract addresses
    function _storeEmission(bytes32 emissionId, Emission memory deployment) internal {
        emissionsById[emissionId] = deployment;
    }

    /// @notice Ensures that an emission does not already exist for the given id
    /// @param emissionId Emission identifier
    /// @dev Reverts with {EmissionAlreadyExists} when an emission is already stored
    function _ensureEmissionDoesNotExist(bytes32 emissionId) internal view {
        if (emissionsById[emissionId].token != address(0)) {
            revert EmissionAlreadyExists(emissionId);
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE) {
        (newImplementation);
    }
}

