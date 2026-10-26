// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";

import {Identity} from "../../../src/identity/Identity.sol";
import {IIdentity} from "../../../src/interfaces/IIdentity.sol";

contract IdentityTest is Test {
    address internal admin = makeAddr("admin");
    address internal other = makeAddr("other");
    bytes32 internal userIdHash = keccak256("user-1");

    Identity internal identity;

    function setUp() public {
        identity = new Identity(admin, userIdHash);
    }

    function test_Constructor_SetsAdminAndUserIdHash() public view {
        assertEq(identity.admin(), admin);
        assertEq(identity.userIdHash(), userIdHash);
    }

    function test_Constructor_RevertsWhenAdminZero() public {
        vm.expectRevert(IIdentity.ZeroAddress.selector);
        new Identity(address(0), userIdHash);
    }

    function test_TransferAdmin_Success() public {
        vm.prank(admin);
        identity.transferAdmin(other);

        assertEq(identity.admin(), other);
    }

    function test_TransferAdmin_RevertsWhenCallerNotAdmin() public {
        vm.prank(other);
        vm.expectRevert(IIdentity.NotAdmin.selector);
        identity.transferAdmin(other);
    }

    function test_TransferAdmin_RevertsWhenNewAdminZero() public {
        vm.prank(admin);
        vm.expectRevert(IIdentity.ZeroAddress.selector);
        identity.transferAdmin(address(0));
    }
}

