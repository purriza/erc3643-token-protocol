// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";

/**
 * @title DeployIdentityFactory
 * @notice Deploys the global IdentityFactory implementation and proxy.
 * @dev Uses DEPLOYER_PRIVATE_KEY as both admin and complianceAdmin for the proxy roles.
 */
contract DeployIdentityFactory is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        IdentityFactory impl = new IdentityFactory();
        bytes memory initData = abi.encodeCall(IdentityFactory.initialize, (admin, admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);

        vm.stopBroadcast();

        console.log("IdentityFactory implementation:", address(impl));
        console.log("IdentityFactory proxy (use this):", address(proxy));
        console.log("Admin / ComplianceAdmin:", admin);
    }
}

