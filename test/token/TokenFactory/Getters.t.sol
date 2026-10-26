// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";

import {TokenFactory} from "../../../src/token/TokenFactory.sol";

/*//////////////////////////////////////////////////////////////
                            GETTERS
//////////////////////////////////////////////////////////////*/

contract TokenFactoryGettersTest is TestSetup {

    function test_Emissions_ReturnsDefaultEmissionAddresses() public view {
        (
            address token,
            address registry,
            address compliance,
            address identityFactory,
            address claimsRegistry,
            address topicsRegistry,
            address issuersRegistry,
            address claimModule,
            address freezeModule,
            address treasuryAddr
        ) = tokenFactory.emissions(DEFAULT_EMISSION_ID);

        assertEq(token, address(emissionToken));
        assertEq(registry, address(emissionRegistry));
        assertEq(compliance, address(emissionCompliance));
        assertNotEq(identityFactory, address(0));
        assertNotEq(claimsRegistry, address(0));
        assertNotEq(topicsRegistry, address(0));
        assertNotEq(issuersRegistry, address(0));
        assertNotEq(claimModule, address(0));
        assertNotEq(freezeModule, address(0));
        assertEq(treasuryAddr, treasuryWallet);
    }

    function test_Emissions_ReturnsZeroForNonExistentEmission() public view {
        (
            address token,
            address registry,
            address compliance,
            address identityFactory,
            address claimsRegistry,
            address topicsRegistry,
            address issuersRegistry,
            address claimModule,
            address freezeModule,
            address treasuryAddr
        ) = tokenFactory.emissions(keccak256("nonexistent"));

        assertEq(token, address(0));
        assertEq(registry, address(0));
        assertEq(compliance, address(0));
        assertEq(identityFactory, address(0));
        assertEq(claimsRegistry, address(0));
        assertEq(topicsRegistry, address(0));
        assertEq(issuersRegistry, address(0));
        assertEq(claimModule, address(0));
        assertEq(freezeModule, address(0));
        assertEq(treasuryAddr, address(0));
    }
}
