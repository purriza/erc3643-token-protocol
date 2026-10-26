// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TokenFactory} from "../../src/token/TokenFactory.sol";
import {EmissionDeployerManager} from "../../src/token/EmissionDeployerManager.sol";

/**
 * @title DeployTokenFactory
     * @notice Deploys TokenFactory implementation and proxy, then initializes with admin.
     * @dev Admin is the deployer (address from DEPLOYER_PRIVATE_KEY).
     *      Requires EMISSION_DEPLOYER_MANAGER and TOPIC_CATALOG_PROXY to be set in .env.
 *      Idempotent only for a fresh chain.
 */
contract DeployTokenFactory is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.addr(deployerKey);

        address emissionDeployerManager = vm.envAddress("EMISSION_DEPLOYER_MANAGER");
        address topicCatalog = vm.envAddress("TOPIC_CATALOG_PROXY");

        vm.startBroadcast(deployerKey);

        TokenFactory impl = new TokenFactory();
        bytes memory initData = abi.encodeCall(
            TokenFactory.initialize,
            (admin, emissionDeployerManager, topicCatalog)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        TokenFactory tokenFactory = TokenFactory(address(proxy));

        // Wire the EmissionDeployerManager so only this TokenFactory proxy can call deployEmissionStack
        EmissionDeployerManager(emissionDeployerManager).setFactory(address(proxy));

        vm.stopBroadcast();

        console.log("TokenFactory implementation:", address(impl));
        console.log("TokenFactory proxy (use this):", address(tokenFactory));
        console.log("Admin:", admin);
        console.log("EmissionDeployerManager:", emissionDeployerManager);
        console.log("TopicCatalog:", topicCatalog);
    }
}
