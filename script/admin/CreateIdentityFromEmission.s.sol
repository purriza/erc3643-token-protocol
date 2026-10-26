// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";

/**
 * @title CreateIdentityFromEmission
 * @notice Creates an identity using the emission's IdentityFactory.
 * @dev Required in .env:
 *      TOKEN_FACTORY_PROXY
 *      EMISSION_ID (raw string; script hashes it with keccak256(bytes(EMISSION_ID)))
 *      IDENTITY_USER_ID_HASH (bytes32, e.g. 0x...)
 *      IDENTITY_ADMIN
 *      Caller must have ADMIN_ROLE in the emission IdentityFactory.
 */
contract CreateIdentityFromEmission is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        string memory emissionIdRaw = vm.envString("EMISSION_ID");
        bytes32 emissionId = keccak256(bytes(emissionIdRaw));
        bytes32 userIdHash = vm.envBytes32("IDENTITY_USER_ID_HASH");
        address identityAdmin = vm.envAddress("IDENTITY_ADMIN");

        (, , , address identityFactoryAddr, , , , , ,) = ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (identityFactoryAddr == address(0)) revert("Emission not found");

        vm.startBroadcast(deployerKey);
        address identity = IdentityFactory(identityFactoryAddr).createIdentity(userIdHash, identityAdmin);
        vm.stopBroadcast();

        console.log("--- Deployed addresses ---");
        console.log("Emission ID (raw):", emissionIdRaw);
        console.log("IdentityFactory:", identityFactoryAddr);
        console.log("Identity:", identity);
        console.log("Identity admin:", identityAdmin);
    }
}
