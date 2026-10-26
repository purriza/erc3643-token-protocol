// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";

import {TokenFactory} from "../../../src/token/TokenFactory.sol";
import {ITokenFactory} from "../../../src/interfaces/ITokenFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/*//////////////////////////////////////////////////////////////
                    INIT / ADMIN / HELPERS
//////////////////////////////////////////////////////////////*/

contract TokenFactoryInitAdminHelpersTest is TestSetup {

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialize_RevertsWhenAdminIsZeroAddress() public {
        TokenFactory impl = new TokenFactory();
        bytes memory initData = abi.encodeCall(TokenFactory.initialize, (address(0), address(1), address(1)));

        vm.expectRevert(ITokenFactory.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_Initialize_RevertsWhenEmissionDeployerManagerIsZeroAddress() public {
        TokenFactory impl = new TokenFactory();
        bytes memory initData = abi.encodeCall(TokenFactory.initialize, (admin, address(0), address(1)));

        vm.expectRevert(ITokenFactory.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_Initialize_RevertsWhenTopicCatalogIsZeroAddress() public {
        TokenFactory impl = new TokenFactory();
        bytes memory initData = abi.encodeCall(TokenFactory.initialize, (admin, address(1), address(0)));

        vm.expectRevert(ITokenFactory.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_Initialize_SetsHelperAndAdmin() public view {
        assertNotEq(address(tokenFactory.emissionDeployerManager()), address(0));
        assertNotEq(address(tokenFactory.topicCatalog()), address(0));
        assertTrue(tokenFactory.hasRole(tokenFactory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(tokenFactory.hasRole(tokenFactory.ADMIN_ROLE(), admin));
    }

    function test_Initialize_DoubleCallReverts() public {
        vm.expectRevert();
        tokenFactory.initialize(admin, address(1), address(1));
    }

    function test_Upgrade_RevertsWhenCallerIsNotUpgrader() public {
        TokenFactory newImplementation = new TokenFactory();
        vm.prank(user1);
        vm.expectRevert();
        tokenFactory.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_Upgrade_SucceedsWhenCallerHasUpgraderRole() public {
        TokenFactory newImplementation = new TokenFactory();
        vm.prank(admin);
        tokenFactory.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN / HELPERS (placeholders)
    //////////////////////////////////////////////////////////////*/

    function test_SetEmissionDeployerManager_UpdatesAddressWhenCalledByAdmin() public {
        address newManager = makeAddr("newManager");

        vm.prank(admin);
        tokenFactory.setEmissionDeployerManager(newManager);

        assertEq(tokenFactory.emissionDeployerManager(), newManager);
    }

    function test_SetEmissionDeployerManager_RevertsWhenCallerIsNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        tokenFactory.setEmissionDeployerManager(makeAddr("newManager"));
    }

    function test_SetEmissionDeployerManager_RevertsWhenAddressIsZero() public {
        vm.prank(admin);
        vm.expectRevert(ITokenFactory.ZeroAddress.selector);
        tokenFactory.setEmissionDeployerManager(address(0));
    }
}
