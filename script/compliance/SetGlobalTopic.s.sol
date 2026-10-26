// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TokenFactory} from "../../src/token/TokenFactory.sol";
import {TopicCatalog} from "../../src/claims/TopicCatalog.sol";

/**
 * @notice Sets a topic in global TopicCatalog (admin operation).
 * @dev Required env:
 *      TOKEN_FACTORY_PROXY, TOPIC_ID, TOPIC_CODE, TOPIC_DESCRIPTION, TOPIC_ACTIVE
 */
contract SetGlobalTopic is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        uint256 topicId = vm.envUint("TOPIC_ID");
        string memory code = vm.envString("TOPIC_CODE");
        string memory description = vm.envString("TOPIC_DESCRIPTION");
        bool active = vm.envBool("TOPIC_ACTIVE");

        address topicCatalogAddr = TokenFactory(tokenFactoryProxy).topicCatalog();

        vm.startBroadcast(deployerKey);
        TopicCatalog(topicCatalogAddr).setTopic(topicId, code, description, active);
        vm.stopBroadcast();

        console.log("TopicCatalog:", topicCatalogAddr);
        console.log("Topic ID:", topicId);
        console.log("Code:", code);
        console.log("Active:", active);
    }
}
