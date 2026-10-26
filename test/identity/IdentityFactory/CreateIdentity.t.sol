// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IdentityFactory} from "../../../src/identity/IdentityFactory.sol";
import {IIdentityFactory} from "../../../src/interfaces/IIdentityFactory.sol";
import {IIdentity} from "../../../src/interfaces/IIdentity.sol";

contract IdentityFactoryCreateIdentityTest is Test {
    address internal admin = makeAddr("admin");
    address internal complianceAdmin = makeAddr("complianceAdmin");
    address internal user = makeAddr("user");
    address internal other = makeAddr("other");

    IdentityFactory internal identityFactory;

    function setUp() public {
        IdentityFactory impl = new IdentityFactory();
        bytes memory initData = abi.encodeCall(IdentityFactory.initialize, (admin, complianceAdmin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        identityFactory = IdentityFactory(address(proxy));
    }

    function test_CreateIdentity_Success() public {
        bytes32 userIdHash = keccak256("user-hash-1");

        vm.prank(admin);
        address identityAddr = identityFactory.createIdentity(userIdHash, user);

        assertNotEq(identityAddr, address(0));
        assertEq(identityFactory.identityByUserIdHash(userIdHash), identityAddr);
        assertEq(IIdentity(identityAddr).admin(), user);
        assertEq(IIdentity(identityAddr).userIdHash(), userIdHash);
    }

    function test_CreateIdentity_RevertsWhenNotAdmin() public {
        vm.prank(other);
        vm.expectRevert();
        identityFactory.createIdentity(keccak256("user-hash-2"), user);
    }

    function test_CreateIdentity_RevertsWhenIdentityAdminZero() public {
        vm.prank(admin);
        vm.expectRevert(IIdentityFactory.ZeroAddress.selector);
        identityFactory.createIdentity(keccak256("user-hash-3"), address(0));
    }

    function test_CreateIdentity_RevertsWhenUserIdHashZero() public {
        vm.prank(admin);
        vm.expectRevert(IIdentityFactory.InvalidUserIdHash.selector);
        identityFactory.createIdentity(bytes32(0), user);
    }

    function test_CreateIdentity_RevertsWhenAlreadyExists() public {
        bytes32 userIdHash = keccak256("user-hash-4");

        vm.prank(admin);
        identityFactory.createIdentity(userIdHash, user);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IIdentityFactory.IdentityAlreadyExists.selector, userIdHash));
        identityFactory.createIdentity(userIdHash, other);
    }
}

