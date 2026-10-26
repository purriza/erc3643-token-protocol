// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ComplianceBase} from "../../src/compliance/ComplianceBase.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeComplianceBase
 * @notice Deploys a new ComplianceBase implementation
 *         and upgrades the proxy at COMPLIANCE_BASE_PROXY.
 * @dev Requires COMPLIANCE_BASE_PROXY in .env.
 *      Caller must have UPGRADER_ROLE on the proxy.
 */
contract UpgradeComplianceBase is Script {
    function run() external {
        address proxyAddress = vm.envAddress("COMPLIANCE_BASE_PROXY");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        ComplianceBase newImpl = new ComplianceBase();
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(address(newImpl), "");

        vm.stopBroadcast();

        console.log("New ComplianceBase implementation:", address(newImpl));
        console.log("Proxy (unchanged):", proxyAddress);
    }
}
