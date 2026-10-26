// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ITopicCatalog} from "../interfaces/ITopicCatalog.sol";

/**
 * @title TopicCatalog
 * @notice Global catalog of available claim topics
 */
contract TopicCatalog is ITopicCatalog, AccessControlUpgradeable, UUPSUpgradeable {

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to execute admin operations (manage topic catalog)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role allowed to upgrade the proxy
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of topics to their data
    mapping(uint256 topic => Topic data) public topics;

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

    /// @inheritdoc ITopicCatalog
    function initialize(address admin) external initializer {
        if (admin == address(0)) revert ZeroAddress();

        __AccessControl_init();

        // Grant roles to the admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITopicCatalog
    function setTopic(uint256 topic, string calldata code, string calldata description, bool active)
        external
        onlyRole(ADMIN_ROLE)
    {
        // Check if the topic is valid  
        if (topic == 0) revert InvalidTopic(topic);
        // Check if the code is valid
        if (bytes(code).length == 0) revert EmptyCode();
        // Check if the topic already exists
        if (topics[topic].exists) revert TopicAlreadyExists(topic);

        // Set the topic
        topics[topic] = Topic({code: code, description: description, exists: true, active: active});

        emit TopicSet(topic, code, description, active);
    }

    /// @inheritdoc ITopicCatalog
    function setTopicActive(uint256 topic, bool active) external onlyRole(ADMIN_ROLE) {
        if (!topics[topic].exists) revert TopicNotFound(topic);

        topics[topic].active = active;

        emit TopicActiveSet(topic, active);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITopicCatalog
    function isTopicActive(uint256 topic) external view returns (bool) {
        Topic memory t = topics[topic];

        return t.exists && t.active;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE) {
        (newImplementation);
    }
}

