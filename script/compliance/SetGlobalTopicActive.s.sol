// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TokenFactory} from "../../src/token/TokenFactory.sol";
import {TopicCatalog} from "../../src/claims/TopicCatalog.sol";

/**
 * @notice Sets active flag for a global topic in TopicCatalog.
 * @dev Required env:
 *      TOKEN_FACTORY_PROXY, TOPIC_ID, TOPIC_ACTIVE
 */
contract SetGlobalTopicActive is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        uint256 topicId = vm.envUint("TOPIC_ID");
        bool active = vm.envBool("TOPIC_ACTIVE");

        address topicCatalogAddr = TokenFactory(tokenFactoryProxy).topicCatalog();

        vm.startBroadcast(deployerKey);
        TopicCatalog(topicCatalogAddr).setTopicActive(topicId, active);
        vm.stopBroadcast();

        console.log("TopicCatalog:", topicCatalogAddr);
        console.log("Topic ID:", topicId);
        console.log("Active:", active);
    }
}
