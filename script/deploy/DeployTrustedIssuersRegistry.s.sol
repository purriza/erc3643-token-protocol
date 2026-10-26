// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TrustedIssuersRegistry} from "../../src/claims/TrustedIssuersRegistry.sol";

/**
 * @title DeployTrustedIssuersRegistry
 * @notice Deploys the global TrustedIssuersRegistry implementation and proxy.
 * @dev Uses DEPLOYER_PRIVATE_KEY as both admin and complianceAdmin.
 */
contract DeployTrustedIssuersRegistry is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        TrustedIssuersRegistry impl = new TrustedIssuersRegistry();
        bytes memory initData = abi.encodeCall(TrustedIssuersRegistry.initialize, (admin, admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);

        vm.stopBroadcast();

        console.log("TrustedIssuersRegistry implementation:", address(impl));
        console.log("TrustedIssuersRegistry proxy (use this):", address(proxy));
        console.log("Admin / ComplianceAdmin:", admin);
    }
}

