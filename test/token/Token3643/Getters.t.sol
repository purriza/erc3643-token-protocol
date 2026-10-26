// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";

import {Token3643} from "../../../src/token/Token3643.sol";

/*//////////////////////////////////////////////////////////////
                            GETTERS
//////////////////////////////////////////////////////////////*/

contract Token3643GettersTest is TestSetup {

    function test_NameAndSymbol() public view {
        assertEq(emissionToken.name(), "TestToken");
        assertEq(emissionToken.symbol(), "TT");
    }

    function test_RegistryComplianceTreasury() public view {
        assertEq(address(emissionToken.registry()), address(emissionRegistry));
        assertEq(address(emissionToken.compliance()), address(emissionCompliance));
        assertEq(emissionToken.treasury(), treasuryWallet);
    }

    function test_TotalSupply_IsInitialSupply() public view {
        assertEq(emissionToken.totalSupply(), DEFAULT_INITIAL_SUPPLY);
    }
}
