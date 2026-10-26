// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {IComplianceBase} from "../../src/interfaces/IComplianceBase.sol";

/**
 * @title WireEmissionCompliance
 * @notice One-off script for existing emissions: sets ComplianceBase.token and adds claim + freeze modules.
 * @dev Use when ComplianceBase was deployed without setToken/addModule (transfers revert with NotTokenCaller).
 *
 * Required in .env:
 *   DEPLOYER_PRIVATE_KEY  – must be the emission admin (ADMIN_ROLE on ComplianceBase)
 *   TOKEN_FACTORY_PROXY
 *   EMISSION_ID            – string, e.g. "emission1"
 *
 * Run:
 *   forge script script/admin/WireEmissionCompliance.s.sol:WireEmissionCompliance --rpc-url <RPC> --broadcast
 */
contract WireEmissionCompliance is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        string memory emissionIdRaw = vm.envString("EMISSION_ID");
        bytes32 emissionId = keccak256(bytes(emissionIdRaw));

        ITokenFactory factory = ITokenFactory(tokenFactoryProxy);
        (
            address token,
            ,
            address compliance,
            ,
            ,
            ,
            ,
            address claimComplianceModule,
            address walletFreezeComplianceModule,
            address emissionTreasury
        ) = factory.emissions(emissionId);

        if (token == address(0) || compliance == address(0)) {
            console.log("Emission not found or not deployed. EMISSION_ID:", emissionIdRaw);
            return;
        }

        console.log("Emission ID (raw):", emissionIdRaw);
        console.log("Token:", token);
        console.log("ComplianceBase:", compliance);
        console.log("ClaimComplianceModule:", claimComplianceModule);
        console.log("WalletFreezeComplianceModule:", walletFreezeComplianceModule);
        console.log("Treasury:", emissionTreasury);

        vm.startBroadcast(deployerKey);

        IComplianceBase(compliance).setToken(token);
        IComplianceBase(compliance).addModule(claimComplianceModule);
        IComplianceBase(compliance).addModule(walletFreezeComplianceModule);

        vm.stopBroadcast();

        console.log("Done: compliance.setToken and addModule(claim), addModule(freeze) executed.");
    }
}
