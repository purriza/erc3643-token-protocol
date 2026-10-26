// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {IdentityRegistry} from "../../src/identity/IdentityRegistry.sol";

/**
 * @title BindWalletIdentity
 * @notice Binds a wallet to an identity in the emission's IdentityRegistry.
 * @dev Required in .env:
 *      TOKEN_FACTORY_PROXY
 *      EMISSION_ID (raw string; script hashes it with keccak256(bytes(EMISSION_ID)))
 *      BIND_WALLET
 *      BIND_IDENTITY
 *      Caller must have COMPLIANCE_ADMIN_ROLE in the emission IdentityRegistry.
 */
contract BindWalletIdentity is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        bytes32 emissionId = keccak256(bytes(vm.envString("EMISSION_ID")));
        address wallet = vm.envAddress("BIND_WALLET");
        address identity = vm.envAddress("BIND_IDENTITY");

        (, address registryAddr, , , , , , , ,) = ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (registryAddr == address(0)) revert("Emission not found");

        vm.startBroadcast(deployerKey);
        IdentityRegistry(registryAddr).setIdentity(wallet, identity);
        vm.stopBroadcast();

        console.log("--- Bound addresses ---");
        console.log("Emission ID (raw):", vm.envString("EMISSION_ID"));
        console.log("IdentityRegistry:", registryAddr);
        console.log("Wallet:", wallet);
        console.log("Identity:", identity);
    }
}
