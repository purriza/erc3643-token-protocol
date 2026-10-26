// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

/**
 * @title ITopicCatalog
 * @notice Interface for the global catalog of available claim topics
 */
interface ITopicCatalog {

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct describing a topic
    /// @param code Topic code
    /// @param description Topic description
    /// @param exists Whether the topic exists in catalog
    /// @param active Whether the topic is active
    struct Topic {
        string code;
        string description;
        bool exists;
        bool active;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a topic is set
    /// @param topic Topic identifier   
    /// @param code Topic code
    /// @param description Topic description
    /// @param active Whether the topic is active
    event TopicSet(uint256 indexed topic, string code, string description, bool active);

    /// @notice Emitted when a topic's active status is set
    /// @param topic Topic identifier
    /// @param active Whether the topic is active
    event TopicActiveSet(uint256 indexed topic, bool active);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when providing an invalid topic
    error InvalidTopic(uint256 topic);

    /// @notice Thrown when a topic already exists
    error TopicAlreadyExists(uint256 topic);
    
    /// @notice Thrown when a topic is not found   
    error TopicNotFound(uint256 topic);

    /// @notice Thrown when the code is empty
    error EmptyCode();

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the TopicCatalog contract
     * @param admin Address that will receive DEFAULT_ADMIN_ROLE, ADMIN_ROLE and UPGRADER_ROLE
     */
    function initialize(address admin) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a topic
     * @param topic Topic identifier
     * @param code Topic code
     * @param description Topic description
     * @param active Whether the topic is active
     */
    function setTopic(uint256 topic, string calldata code, string calldata description, bool active) external;

    /**
     * @notice Sets a topic's active status
     * @param topic Topic identifier
     * @param active Whether the topic is active
     */
    function setTopicActive(uint256 topic, bool active) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns topic data from storage mapping
     * @param topic Topic identifier
     * @return code Topic code
     * @return description Topic description
     * @return exists Whether the topic exists
     * @return active Whether the topic is active
     */
    function topics(uint256 topic)
        external
        view
        returns (string memory code, string memory description, bool exists, bool active);

    /**
     * @notice Returns whether a topic is active
     * @param topic Topic identifier
     * @return active Whether the topic is active
     */
    function isTopicActive(uint256 topic) external view returns (bool);
}

