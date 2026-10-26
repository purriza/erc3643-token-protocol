// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";

import {Token3643} from "../../../src/token/Token3643.sol";

/*//////////////////////////////////////////////////////////////
                    MAX SUPPLY & CONSTRUCTOR MINT
//////////////////////////////////////////////////////////////*/

contract Token3643FinalizeMintingTest is TestSetup {

    function test_Constructor_MintsInitialSupplyToTreasury() public view {
        assertEq(emissionToken.totalSupply(), DEFAULT_INITIAL_SUPPLY);
        assertEq(emissionToken.balanceOf(treasuryWallet), DEFAULT_INITIAL_SUPPLY);
    }
}
