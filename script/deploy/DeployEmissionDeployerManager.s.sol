// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {EmissionDeployerManager} from "../../src/token/EmissionDeployerManager.sol";

/**
 * @title DeployEmissionDeployerManager
 * @notice Deploys the EmissionDeployerManager helper contract.
 * @dev Uses DEPLOYER_PRIVATE_KEY as admin; requires global contracts (topicCatalog, identityFactory, claims, issuers).
 */
contract DeployEmissionDeployerManager is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.addr(deployerKey);
        address topicCatalog = vm.envAddress("TOPIC_CATALOG_PROXY");
        address claimsRegistry = vm.envAddress("CLAIMS_REGISTRY_PROXY");
        address trustedIssuersRegistry = vm.envAddress("TRUSTED_ISSUERS_REGISTRY_PROXY");
        address identityFactory = vm.envAddress("IDENTITY_FACTORY_PROXY");

        vm.startBroadcast(deployerKey);
        EmissionDeployerManager manager =
            new EmissionDeployerManager(admin, topicCatalog, claimsRegistry, trustedIssuersRegistry, identityFactory);
        vm.stopBroadcast();

        console.log("EmissionDeployerManager:", address(manager));
        console.log("Admin:", admin);
        console.log("TopicCatalog (global):", topicCatalog);
        console.log("IdentityFactory (global):", identityFactory);
    }
}

