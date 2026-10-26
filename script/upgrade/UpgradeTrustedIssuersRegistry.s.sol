// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TrustedIssuersRegistry} from "../../src/claims/TrustedIssuersRegistry.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeTrustedIssuersRegistry
 * @notice Deploys a new TrustedIssuersRegistry implementation
 *         and upgrades the proxy at TRUSTED_ISSUERS_REGISTRY_PROXY.
 * @dev Requires TRUSTED_ISSUERS_REGISTRY_PROXY in .env.
 *      Caller must have UPGRADER_ROLE on the proxy.
 */
contract UpgradeTrustedIssuersRegistry is Script {
    function run() external {
        address proxyAddress = vm.envAddress("TRUSTED_ISSUERS_REGISTRY_PROXY");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        TrustedIssuersRegistry newImpl = new TrustedIssuersRegistry();
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(address(newImpl), "");

        vm.stopBroadcast();

        console.log("New TrustedIssuersRegistry implementation:", address(newImpl));
        console.log("Proxy (unchanged):", proxyAddress);
    }
}
