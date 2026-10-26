// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {TestSetup} from "../../TestSetup.t.sol";

import {IIdentityRegistry} from "../../../src/interfaces/IIdentityRegistry.sol";

/*//////////////////////////////////////////////////////////////
                        SET IDENTITY
//////////////////////////////////////////////////////////////*/

contract IdentityRegistrySetIdentityTest is TestSetup {
    function test_SetIdentity_UpdatesIdentity() public {
        vm.prank(admin);
        emissionRegistry.setIdentity(user1, address(0x1234));
        assertEq(emissionRegistry.identityOf(user1), address(0x1234));
    }

    function test_SetIdentity_RevertsWhenNotComplianceAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        emissionRegistry.setIdentity(user2, address(0x1234));
    }

    function test_SetIdentity_RevertsWhenZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        emissionRegistry.setIdentity(address(0), address(0x1234));

        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        emissionRegistry.setIdentity(user1, address(0));
        vm.stopPrank();
    }

    function test_SetIdentities_UpdatesIdentityBatch() public {
        address[] memory wallets = new address[](2);
        address[] memory identities = new address[](2);
        wallets[0] = user1;
        wallets[1] = user2;
        identities[0] = address(0x1111);
        identities[1] = address(0x2222);

        vm.prank(admin);
        emissionRegistry.setIdentities(wallets, identities);

        assertEq(emissionRegistry.identityOf(user1), address(0x1111));
        assertEq(emissionRegistry.identityOf(user2), address(0x2222));
    }

    function test_SetIdentities_RevertsWhenArrayLengthMismatch() public {
        address[] memory wallets = new address[](2);
        address[] memory identities = new address[](1);
        wallets[0] = user1;
        wallets[1] = user2;
        identities[0] = address(0x1111);

        vm.prank(admin);
        vm.expectRevert(IIdentityRegistry.InvalidArrayLength.selector);
        emissionRegistry.setIdentities(wallets, identities);
    }

    function test_SetIdentities_RevertsWhenNotComplianceAdmin() public {
        address[] memory wallets = new address[](1);
        address[] memory identities = new address[](1);
        wallets[0] = user1;
        identities[0] = address(0x1111);

        vm.prank(user1);
        vm.expectRevert();
        emissionRegistry.setIdentities(wallets, identities);
    }

    function test_SetIdentities_RevertsWhenAnyWalletOrIdentityIsZero() public {
        address[] memory wallets = new address[](1);
        address[] memory identities = new address[](1);

        wallets[0] = address(0);
        identities[0] = address(0x1111);
        vm.prank(admin);
        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        emissionRegistry.setIdentities(wallets, identities);

        wallets[0] = user1;
        identities[0] = address(0);
        vm.prank(admin);
        vm.expectRevert(IIdentityRegistry.ZeroAddress.selector);
        emissionRegistry.setIdentities(wallets, identities);
    }
}

