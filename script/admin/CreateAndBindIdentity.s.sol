// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";
import {IdentityRegistry} from "../../src/identity/IdentityRegistry.sol";

/**
 * @title CreateAndBindIdentity
 * @notice Creates a new identity and binds it to a wallet in one script run.
 * @dev Required in .env:
 *      TOKEN_FACTORY_PROXY
 *      EMISSION_ID (raw string; script hashes it with keccak256(bytes(EMISSION_ID)))
 *      IDENTITY_USER_ID_HASH (bytes32, e.g. 0x...)
 *      IDENTITY_ADMIN
 *      BIND_WALLET
 *      Caller must have:
 *      - ADMIN_ROLE in emission IdentityFactory
 *      - COMPLIANCE_ADMIN_ROLE in emission IdentityRegistry
 */
contract CreateAndBindIdentity is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        bytes32 emissionId = keccak256(bytes(vm.envString("EMISSION_ID")));
        bytes32 userIdHash = vm.envBytes32("IDENTITY_USER_ID_HASH");
        address identityAdmin = vm.envAddress("IDENTITY_ADMIN");
        address wallet = vm.envAddress("BIND_WALLET");

        (, address registryAddr, , address identityFactoryAddr, , , , , ,) =
            ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (registryAddr == address(0) || identityFactoryAddr == address(0)) revert("Emission not found");

        vm.startBroadcast(deployerKey);
        address identity = IdentityFactory(identityFactoryAddr).createIdentity(userIdHash, identityAdmin);
        IdentityRegistry(registryAddr).setIdentity(wallet, identity);
        vm.stopBroadcast();

        console.log("--- Deployed and bound addresses ---");
        console.log("Emission ID (raw):", vm.envString("EMISSION_ID"));
        console.log("IdentityFactory:", identityFactoryAddr);
        console.log("IdentityRegistry:", registryAddr);
        console.log("Identity:", identity);
        console.log("Identity admin:", identityAdmin);
        console.log("Wallet:", wallet);
    }
}
