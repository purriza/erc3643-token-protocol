// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {TrustedIssuersRegistry} from "../../src/claims/TrustedIssuersRegistry.sol";

/**
 * @notice Sets trusted issuer status in emission TrustedIssuersRegistry.
 * @dev Required env:
 *      TOKEN_FACTORY_PROXY, EMISSION_ID, ISSUER, ISSUER_TRUSTED
 */
contract SetEmissionTrustedIssuer is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        bytes32 emissionId = keccak256(bytes(vm.envString("EMISSION_ID")));
        address issuer = vm.envAddress("ISSUER");
        bool trusted = vm.envBool("ISSUER_TRUSTED");

        (, , , , , , address issuersRegistryAddr, , ,) = ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (issuersRegistryAddr == address(0)) revert("Emission not found");

        vm.startBroadcast(deployerKey);
        TrustedIssuersRegistry(issuersRegistryAddr).setTrustedIssuer(issuer, trusted);
        vm.stopBroadcast();

        console.log("EmissionId:");
        console.logBytes32(emissionId);
        console.log("TrustedIssuersRegistry:", issuersRegistryAddr);
        console.log("Issuer:", issuer);
        console.log("Trusted:", trusted);
    }
}
