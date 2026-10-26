// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {ClaimsRegistry} from "../../src/claims/ClaimsRegistry.sol";

/**
 * @notice Sets a claim in emission ClaimsRegistry.
 * @dev Required env:
 *      TOKEN_FACTORY_PROXY, EMISSION_ID, CLAIM_IDENTITY, CLAIM_TOPIC, CLAIM_DATA_HASH, CLAIM_VALID_TO
 */
contract SetEmissionClaim is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        bytes32 emissionId = keccak256(bytes(vm.envString("EMISSION_ID")));
        address identity = vm.envAddress("CLAIM_IDENTITY");
        uint256 topic = vm.envUint("CLAIM_TOPIC");
        bytes32 dataHash = vm.envBytes32("CLAIM_DATA_HASH");
        uint64 validTo = uint64(vm.envUint("CLAIM_VALID_TO"));

        (, , , , address claimsRegistryAddr, , , , ,) = ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (claimsRegistryAddr == address(0)) revert("Emission not found");

        vm.startBroadcast(deployerKey);
        ClaimsRegistry(claimsRegistryAddr).setClaim(identity, topic, dataHash, validTo);
        vm.stopBroadcast();

        console.log("EmissionId:");
        console.logBytes32(emissionId);
        console.log("ClaimsRegistry:", claimsRegistryAddr);
        console.log("Identity:", identity);
        console.log("Topic:", topic);
        console.log("ValidTo:", validTo);
    }
}
