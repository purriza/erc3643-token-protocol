// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TopicCatalog} from "../../src/claims/TopicCatalog.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeTopicCatalog
 * @notice Deploys a new TopicCatalog implementation
 *         and upgrades the proxy at TOPIC_CATALOG_PROXY.
 * @dev Requires TOPIC_CATALOG_PROXY in .env.
 *      Caller must have UPGRADER_ROLE on the proxy.
 */
contract UpgradeTopicCatalog is Script {
    function run() external {
        address proxyAddress = vm.envAddress("TOPIC_CATALOG_PROXY");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        TopicCatalog newImpl = new TopicCatalog();
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(address(newImpl), "");

        vm.stopBroadcast();

        console.log("New TopicCatalog implementation:", address(newImpl));
        console.log("Proxy (unchanged):", proxyAddress);
    }
}
