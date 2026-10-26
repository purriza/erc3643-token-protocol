// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IClaimTopicsRegistry} from "../interfaces/IClaimTopicsRegistry.sol";
import {ITopicCatalog} from "../interfaces/ITopicCatalog.sol";

/**
 * @title ClaimTopicsRegistry
 * @notice Registry of required claim topics for compliance checks.
 */
contract ClaimTopicsRegistry is IClaimTopicsRegistry, AccessControlUpgradeable, UUPSUpgradeable {
    
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to execute admin operations (manage required topics)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role allowed to upgrade the proxy
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Array of required topics
    uint256[] public topics;

    /// @notice Global topic catalog used to validate topics before requiring them
    ITopicCatalog public topicCatalog;

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

    /// @inheritdoc IClaimTopicsRegistry
    function initialize(address admin, address complianceAdmin, address topicCatalog_) external initializer {
        if (admin == address(0) || complianceAdmin == address(0) || topicCatalog_ == address(0)) revert ZeroAddress();

        __AccessControl_init();
        topicCatalog = ITopicCatalog(topicCatalog_);

        // Grant roles to the admin and compliance admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, complianceAdmin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN / EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IClaimTopicsRegistry
    function addTopic(uint256 topic) external onlyRole(ADMIN_ROLE) {
        // Check if the topic is valid
        if (topic == 0) revert InvalidTopic(topic);
        // Check if the topic is active
        if (!topicCatalog.isTopicActive(topic)) revert TopicNotInCatalog(topic);
        // Check if the topic is already required
        if (_topicExists(topic)) revert TopicAlreadyRequired(topic);

        topics.push(topic);

        emit TopicAdded(topic);
    }

    /// @inheritdoc IClaimTopicsRegistry
    function removeTopic(uint256 topic) external onlyRole(ADMIN_ROLE) {
        if (topic == 0) revert InvalidTopic(topic);

        uint256 length = topics.length;
        for (uint256 i = 0; i < length; i++) {
            if (topics[i] == topic) {
                uint256 lastIndex = length - 1;
                if (i != lastIndex) {
                    topics[i] = topics[lastIndex];
                }
                topics.pop();
                emit TopicRemoved(topic);
                return;
            }
        }

        revert TopicNotRequired(topic);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IClaimTopicsRegistry
    function topicsCount() external view returns (uint256) {
        return topics.length;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if a topic is already required
    /// @param topic Topic to check
    /// @return exists Whether the topic is already required
    function _topicExists(uint256 topic) internal view returns (bool) {
        uint256 length = topics.length;
        for (uint256 i = 0; i < length; i++) {
            if (topics[i] == topic) {
                return true;
            }
        }
        return false;
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE) {
        (newImplementation);
    }
}

