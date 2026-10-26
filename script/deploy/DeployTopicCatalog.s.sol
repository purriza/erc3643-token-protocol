// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TopicCatalog} from "../../src/claims/TopicCatalog.sol";

/**
 * @title DeployTopicCatalog
 * @notice Deploys the global TopicCatalog implementation and proxy.
 * @dev Uses DEPLOYER_PRIVATE_KEY as admin for the TopicCatalog.
 */
contract DeployTopicCatalog is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        TopicCatalog impl = new TopicCatalog();
        bytes memory initData = abi.encodeCall(TopicCatalog.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);

        vm.stopBroadcast();

        console.log("TopicCatalog implementation:", address(impl));
        console.log("TopicCatalog proxy (use this):", address(proxy));
        console.log("Admin:", admin);
    }
}

