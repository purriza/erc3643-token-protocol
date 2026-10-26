// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {ComplianceBase} from "../../src/compliance/ComplianceBase.sol";

/**
 * @title AddComplianceModule
 * @notice Adds a module to the emission's ComplianceBase. Caller must have ADMIN_ROLE on ComplianceBase.
 *        The module must implement IComplianceModule.
 * @dev Required env: TOKEN_FACTORY_PROXY, EMISSION_ID, MODULE_TO_ADD (address of module to add).
 *      DEPLOYER_PRIVATE_KEY (or the key of an address with ADMIN_ROLE).
 */
contract AddComplianceModule is Script {
    function run() external {
        uint256 adminKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        string memory emissionIdRaw = vm.envString("EMISSION_ID");
        address moduleToAdd = vm.envAddress("MODULE_TO_ADD");
        bytes32 emissionId = keccak256(bytes(emissionIdRaw));

        if (moduleToAdd == address(0)) revert("MODULE_TO_ADD must be set");

        (, , address complianceAddr, , , , , , , ) = ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (complianceAddr == address(0)) revert("Emission not found");

        vm.startBroadcast(adminKey);
        ComplianceBase(complianceAddr).addModule(moduleToAdd);
        vm.stopBroadcast();

        console.log("Added module to ComplianceBase:");
        console.log("  ComplianceBase:", complianceAddr);
        console.log("  Module added:", moduleToAdd);
    }
}
