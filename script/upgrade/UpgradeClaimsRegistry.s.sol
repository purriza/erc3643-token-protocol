// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ClaimsRegistry} from "../../src/claims/ClaimsRegistry.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeClaimsRegistry
 * @notice Deploys a new ClaimsRegistry implementation
 *         and upgrades the proxy at CLAIMS_REGISTRY_PROXY.
 * @dev Requires CLAIMS_REGISTRY_PROXY in .env.
 *      Caller must have UPGRADER_ROLE on the proxy.
 */
contract UpgradeClaimsRegistry is Script {
    function run() external {
        address proxyAddress = vm.envAddress("CLAIMS_REGISTRY_PROXY");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        ClaimsRegistry newImpl = new ClaimsRegistry();
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(address(newImpl), "");

        vm.stopBroadcast();

        console.log("New ClaimsRegistry implementation:", address(newImpl));
        console.log("Proxy (unchanged):", proxyAddress);
    }
}
