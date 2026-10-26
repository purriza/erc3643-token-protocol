// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IdentityRegistry} from "../../src/identity/IdentityRegistry.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeIdentityRegistry
 * @notice Deploys a new IdentityRegistry implementation
 *         and upgrades the proxy at IDENTITY_REGISTRY_PROXY.
 * @dev Requires IDENTITY_REGISTRY_PROXY in .env.
 *      Caller must have UPGRADER_ROLE on the proxy.
 */
contract UpgradeIdentityRegistry is Script {
    function run() external {
        address proxyAddress = vm.envAddress("IDENTITY_REGISTRY_PROXY");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        IdentityRegistry newImpl = new IdentityRegistry();
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(address(newImpl), "");

        vm.stopBroadcast();

        console.log("New IdentityRegistry implementation:", address(newImpl));
        console.log("Proxy (unchanged):", proxyAddress);
    }
}
