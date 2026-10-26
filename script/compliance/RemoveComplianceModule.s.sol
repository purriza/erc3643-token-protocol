// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {ComplianceBase} from "../../src/compliance/ComplianceBase.sol";

/**
 * @title RemoveComplianceModule
 * @notice Removes a module from the emission's ComplianceBase. Caller must have ADMIN_ROLE on ComplianceBase.
 * @dev Required env: TOKEN_FACTORY_PROXY, EMISSION_ID, MODULE_TO_REMOVE (address of module to remove).
 *      DEPLOYER_PRIVATE_KEY (or the key of an address with ADMIN_ROLE).
 */
contract RemoveComplianceModule is Script {
    function run() external {
        uint256 adminKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        string memory emissionIdRaw = vm.envString("EMISSION_ID");
        address moduleToRemove = vm.envAddress("MODULE_TO_REMOVE");
        bytes32 emissionId = keccak256(bytes(emissionIdRaw));

        if (moduleToRemove == address(0)) revert("MODULE_TO_REMOVE must be set");

        (, , address complianceAddr, , , , , , , ) = ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (complianceAddr == address(0)) revert("Emission not found");

        vm.startBroadcast(adminKey);
        ComplianceBase(complianceAddr).removeModule(moduleToRemove);
        vm.stopBroadcast();

        console.log("Removed module from ComplianceBase:");
        console.log("  ComplianceBase:", complianceAddr);
        console.log("  Module removed:", moduleToRemove);
    }
}
