// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TokenFactory} from "../../src/token/TokenFactory.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeTokenFactory
 * @notice Deploys a new TokenFactory implementation
 *         and upgrades the proxy at TOKEN_FACTORY_PROXY.
 * @dev Requires TOKEN_FACTORY_PROXY in .env.
 *      Caller must have UPGRADER_ROLE on the proxy.
 */
contract UpgradeTokenFactory is Script {
    function run() external {
        address proxyAddress = vm.envAddress("TOKEN_FACTORY_PROXY");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        TokenFactory newImpl = new TokenFactory();
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(address(newImpl), "");

        vm.stopBroadcast();

        console.log("New TokenFactory implementation:", address(newImpl));
        console.log("Proxy (unchanged):", proxyAddress);
    }
}
