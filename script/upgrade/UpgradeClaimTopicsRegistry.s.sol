// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ClaimTopicsRegistry} from "../../src/claims/ClaimTopicsRegistry.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeClaimTopicsRegistry
 * @notice Deploys a new ClaimTopicsRegistry implementation
 *         and upgrades the proxy at CLAIM_TOPICS_REGISTRY_PROXY.
 * @dev Requires CLAIM_TOPICS_REGISTRY_PROXY in .env.
 *      Caller must have UPGRADER_ROLE on the proxy.
 */
contract UpgradeClaimTopicsRegistry is Script {
    function run() external {
        address proxyAddress = vm.envAddress("CLAIM_TOPICS_REGISTRY_PROXY");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        ClaimTopicsRegistry newImpl = new ClaimTopicsRegistry();
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(address(newImpl), "");

        vm.stopBroadcast();

        console.log("New ClaimTopicsRegistry implementation:", address(newImpl));
        console.log("Proxy (unchanged):", proxyAddress);
    }
}
