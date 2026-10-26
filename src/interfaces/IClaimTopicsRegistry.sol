// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

/**
 * @title IClaimTopicsRegistry
 * @notice Interface for the registry of claim topics
 */
interface IClaimTopicsRegistry {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a topic is added
    event TopicAdded(uint256 indexed topic);

    /// @notice Emitted when a topic is removed
    event TopicRemoved(uint256 indexed topic);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when providing an invalid topic
    error InvalidTopic(uint256 topic);

    /// @notice Thrown when a topic is already required
    error TopicAlreadyRequired(uint256 topic);

    /// @notice Thrown when a topic is not required
    error TopicNotRequired(uint256 topic);

    /// @notice Thrown when a topic is not active in the global topic catalog
    error TopicNotInCatalog(uint256 topic);

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the ClaimTopicsRegistry contract
     * @param admin Address that will receive the DEFAULT_ADMIN_ROLE, ADMIN_ROLE and UPGRADER_ROLE
     * @param complianceAdmin Address that will also receive the ADMIN_ROLE
     * @param topicCatalog Address of the global TopicCatalog contract
     */
    function initialize(address admin, address complianceAdmin, address topicCatalog) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a topic to the registry
     * @param topic Topic to add
     */
    function addTopic(uint256 topic) external;

    /**
     * @notice Removes a topic from the registry
     * @param topic Topic to remove
     */
    function removeTopic(uint256 topic) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the topic at a given index
     * @param index Index in the topics array
     * @return topic Topic at the index
     */
    function topics(uint256 index) external view returns (uint256 topic);

    /**
     * @notice Returns the number of topics in the registry
     * @return count Number of topics in the registry
     */
    function topicsCount() external view returns (uint256);
}

