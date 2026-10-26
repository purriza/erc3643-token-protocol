// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";

import {Token3643} from "../../../src/token/Token3643.sol";
import {IToken3643} from "../../../src/interfaces/IToken3643.sol";
import {IIdentityRegistry} from "../../../src/interfaces/IIdentityRegistry.sol";

/*//////////////////////////////////////////////////////////////
                        FORCED TRANSFER
//////////////////////////////////////////////////////////////*/

contract Token3643ForcedTransferTest is TestSetup {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    // ZeroAddress(), ReceiverNotActive(), SenderFrozen(), ReceiverFrozen(), RevokedOnlyToTreasury(), ComplianceRejected()

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        STATE CHANGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ForcedTransfer_FromTreasuryToUser_MovesBalance() public {
        uint256 amount = 100 ether;
        vm.prank(admin);
        emissionToken.forcedTransfer(treasuryWallet, user1, amount);

        assertEq(emissionToken.balanceOf(user1), amount);
        assertEq(emissionToken.balanceOf(treasuryWallet), DEFAULT_INITIAL_SUPPLY - amount);
    }

    function test_ForcedTransfer_FromUserToUser_MovesBalance() public {
        uint256 amount = 50 ether;
        vm.prank(admin);
        emissionToken.forcedTransfer(treasuryWallet, user1, amount);

        vm.prank(admin);
        emissionToken.forcedTransfer(user1, user2, amount);

        assertEq(emissionToken.balanceOf(user2), amount);
        assertEq(emissionToken.balanceOf(user1), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ForcedTransfer_RevertsWhenNotAgent() public {
        vm.prank(user1);
        vm.expectRevert();
        emissionToken.forcedTransfer(treasuryWallet, user2, 1 ether);
    }

    function test_ForcedTransfer_RevertsWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IToken3643.ZeroAddress.selector);
        emissionToken.forcedTransfer(address(0), user1, 1 ether);

        vm.prank(admin);
        vm.expectRevert(IToken3643.ZeroAddress.selector);
        emissionToken.forcedTransfer(treasuryWallet, address(0), 1 ether);
    }

    // Receiver-not-active semantics are now handled by compliance modules and claims.
}
