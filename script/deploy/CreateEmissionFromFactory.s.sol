// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {IComplianceBase} from "../../src/interfaces/IComplianceBase.sol";

/**
 * @title CreateEmissionFromFactory
 * @notice Calls TokenFactory.createEmission to deploy a full emission stack.
 * @dev Required in .env:
 *      TOKEN_FACTORY_PROXY
 *      EMISSION_ID
 *      EMISSION_NAME
 *      EMISSION_SYMBOL
 *      EMISSION_MAX_SUPPLY
 *      EMISSION_TREASURY
 *      EMISSION_ADMIN
 *      EMISSION_COMPLIANCE_ADMIN
 *      EMISSION_AGENT
 *
 *      EMISSION_ID is read as string and hashed as keccak256(bytes(EMISSION_ID)).
 */
contract CreateEmissionFromFactory is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        string memory emissionIdRaw = vm.envString("EMISSION_ID");

        bytes32 emissionId = keccak256(bytes(emissionIdRaw));
        ITokenFactory factory = ITokenFactory(tokenFactoryProxy);

        address token;
        address registry;
        address compliance;

        vm.startBroadcast(deployerKey);

        (token, registry, compliance) =
            factory.createEmission(
                emissionId,
                vm.envString("EMISSION_NAME"),
                vm.envString("EMISSION_SYMBOL"),
                vm.envUint("EMISSION_MAX_SUPPLY"),
                vm.envAddress("EMISSION_TREASURY"),
                vm.envAddress("EMISSION_ADMIN"),
                vm.envAddress("EMISSION_COMPLIANCE_ADMIN"),
                vm.envAddress("EMISSION_AGENT")
            );

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            address claimComplianceModule,
            address walletFreezeComplianceModule,
            address emissionTreasury
        ) = factory.emissions(emissionId);

        // Wire compliance so onlyToken and modules work (required for transfers)
        IComplianceBase(compliance).setToken(token);
        IComplianceBase(compliance).addModule(claimComplianceModule);
        IComplianceBase(compliance).addModule(walletFreezeComplianceModule);

        vm.stopBroadcast();

        address identityFactory;
        address claimsRegistry;
        address claimTopicsRegistry;
        address trustedIssuersRegistry;

        (
            ,
            ,
            ,
            identityFactory,
            claimsRegistry,
            claimTopicsRegistry,
            trustedIssuersRegistry,
            claimComplianceModule,
            walletFreezeComplianceModule,
            emissionTreasury
        ) = factory.emissions(emissionId);

        console.log("Emission ID (raw):", emissionIdRaw);
        console.logBytes32(emissionId);
        console.log("Token:", token);
        console.log("IdentityRegistry:", registry);
        console.log("ComplianceBase:", compliance);
        console.log("IdentityFactory:", identityFactory);
        console.log("ClaimsRegistry:", claimsRegistry);
        console.log("ClaimTopicsRegistry:", claimTopicsRegistry);
        console.log("TrustedIssuersRegistry:", trustedIssuersRegistry);
        console.log("ClaimComplianceModule:", claimComplianceModule);
        console.log("WalletFreezeComplianceModule:", walletFreezeComplianceModule);
        console.log("Treasury:", emissionTreasury);
    }
}

