// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ClaimsRegistry} from "../../src/claims/ClaimsRegistry.sol";

/**
 * @title DeployClaimsRegistry
 * @notice Deploys the global ClaimsRegistry implementation and proxy.
 * @dev Uses DEPLOYER_PRIVATE_KEY as admin and complianceAdmin.
 *      Requires TOPIC_CATALOG_PROXY and TRUSTED_ISSUERS_REGISTRY_PROXY in .env.
 */
contract DeployClaimsRegistry is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.addr(deployerKey);

        address topicCatalog = vm.envAddress("TOPIC_CATALOG_PROXY");
        address trustedIssuersRegistry = vm.envAddress("TRUSTED_ISSUERS_REGISTRY_PROXY");

        vm.startBroadcast(deployerKey);

        ClaimsRegistry impl = new ClaimsRegistry();
        bytes memory initData =
            abi.encodeCall(ClaimsRegistry.initialize, (admin, admin, trustedIssuersRegistry, topicCatalog));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);

        vm.stopBroadcast();

        console.log("ClaimsRegistry implementation:", address(impl));
        console.log("ClaimsRegistry proxy (use this):", address(proxy));
        console.log("Admin / ComplianceAdmin:", admin);
        console.log("TrustedIssuersRegistry (global):", trustedIssuersRegistry);
        console.log("TopicCatalog (global):", topicCatalog);
    }
}

