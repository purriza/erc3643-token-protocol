// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {ComplianceBase} from "../../src/compliance/ComplianceBase.sol";

/**
 * @notice Pauses emission ComplianceBase.
 * @dev Required env:
 *      TOKEN_FACTORY_PROXY, EMISSION_ID
 */
contract PauseEmissionCompliance is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        bytes32 emissionId = keccak256(bytes(vm.envString("EMISSION_ID")));

        (, , address complianceAddr, , , , , , , ) = ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (complianceAddr == address(0)) revert("Emission not found");

        vm.startBroadcast(deployerKey);
        ComplianceBase(complianceAddr).pause();
        vm.stopBroadcast();

        console.log("EmissionId:");
        console.logBytes32(emissionId);
        console.log("ComplianceBase paused:", complianceAddr);
    }
}
