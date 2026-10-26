// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {ClaimTopicsRegistry} from "../../src/claims/ClaimTopicsRegistry.sol";

/**
 * @notice Removes required topic from emission ClaimTopicsRegistry.
 * @dev Required env:
 *      TOKEN_FACTORY_PROXY, EMISSION_ID, TOPIC_ID
 */
contract RemoveEmissionRequiredTopic is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        bytes32 emissionId = keccak256(bytes(vm.envString("EMISSION_ID")));
        uint256 topicId = vm.envUint("TOPIC_ID");

        (, , , , , address topicsRegistryAddr, , , ,) = ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (topicsRegistryAddr == address(0)) revert("Emission not found");

        vm.startBroadcast(deployerKey);
        ClaimTopicsRegistry(topicsRegistryAddr).removeTopic(topicId);
        vm.stopBroadcast();

        console.log("EmissionId:");
        console.logBytes32(emissionId);
        console.log("ClaimTopicsRegistry:", topicsRegistryAddr);
        console.log("Required topic removed:", topicId);
    }
}
