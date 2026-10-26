// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";

import {ITokenFactory} from "../../../src/interfaces/ITokenFactory.sol";
import {EmissionDeployerManager} from "../../../src/token/EmissionDeployerManager.sol";

/*//////////////////////////////////////////////////////////////
                    INIT / ADMIN / HELPERS
//////////////////////////////////////////////////////////////*/

contract EmissionDeployerManagerInitAdminHelpersTest is Test {
    address public admin = address(0xA11CE);
    address public topicCatalog = address(0xC0FFEE);          // dummy non-zero address
    address public claimsRegistry = address(0xC1A1C5);        // dummy non-zero address
    address public trustedIssuersRegistry = address(0x155123); // dummy non-zero address
    address public identityFactory = address(0x1D1F4c7);    // dummy non-zero address
    address public factory = address(0xFACADE);               // dummy non-zero address

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertsWhenAdminIsZeroAddress() public {
        vm.expectRevert(EmissionDeployerManager.ZeroAddress.selector);
        new EmissionDeployerManager(address(0), topicCatalog, claimsRegistry, trustedIssuersRegistry, identityFactory);
    }

    function test_Constructor_RevertsWhenTopicCatalogIsZeroAddress() public {
        vm.expectRevert(EmissionDeployerManager.ZeroAddress.selector);
        new EmissionDeployerManager(admin, address(0), claimsRegistry, trustedIssuersRegistry, identityFactory);
    }

    function test_Constructor_RevertsWhenClaimsRegistryIsZeroAddress() public {
        vm.expectRevert(EmissionDeployerManager.ZeroAddress.selector);
        new EmissionDeployerManager(admin, topicCatalog, address(0), trustedIssuersRegistry, identityFactory);
    }

    function test_Constructor_RevertsWhenTrustedIssuersRegistryIsZeroAddress() public {
        vm.expectRevert(EmissionDeployerManager.ZeroAddress.selector);
        new EmissionDeployerManager(admin, topicCatalog, claimsRegistry, address(0), identityFactory);
    }

    function test_Constructor_RevertsWhenIdentityFactoryIsZeroAddress() public {
        vm.expectRevert(EmissionDeployerManager.ZeroAddress.selector);
        new EmissionDeployerManager(admin, topicCatalog, claimsRegistry, trustedIssuersRegistry, address(0));
    }

    function test_SetFactory_SetsFactoryOnce() public {
        EmissionDeployerManager manager =
            new EmissionDeployerManager(admin, topicCatalog, claimsRegistry, trustedIssuersRegistry, identityFactory);

        // First call by admin with non-zero address succeeds
        vm.prank(admin);
        manager.setFactory(factory);
        assertEq(manager.factory(), factory);
    }

    function test_SetFactory_RevertsWhenNonAdminCalls() public {
        EmissionDeployerManager manager =
            new EmissionDeployerManager(admin, topicCatalog, claimsRegistry, trustedIssuersRegistry, identityFactory);

        vm.prank(address(0xBEEF));
        vm.expectRevert(EmissionDeployerManager.ZeroAddress.selector);
        manager.setFactory(factory);
    }

    function test_SetFactory_RevertsWhenZeroAddress() public {
        EmissionDeployerManager manager =
            new EmissionDeployerManager(admin, topicCatalog, claimsRegistry, trustedIssuersRegistry, identityFactory);

        vm.prank(admin);
        vm.expectRevert(EmissionDeployerManager.ZeroAddress.selector);
        manager.setFactory(address(0));
    }

    function test_SetFactory_RevertsWhenAlreadySet() public {
        EmissionDeployerManager manager =
            new EmissionDeployerManager(admin, topicCatalog, claimsRegistry, trustedIssuersRegistry, identityFactory);

        vm.prank(admin);
        manager.setFactory(factory);

        vm.prank(admin);
        vm.expectRevert(EmissionDeployerManager.ZeroAddress.selector);
        manager.setFactory(address(0xDEAD));
    }

    function test_DeployEmissionStack_RevertsWhenCallerIsNotFactory() public {
        EmissionDeployerManager manager =
            new EmissionDeployerManager(admin, topicCatalog, claimsRegistry, trustedIssuersRegistry, identityFactory);

        ITokenFactory.EmissionInput memory input = ITokenFactory.EmissionInput({
            name: "Test",
            symbol: "TST",
            maxSupply: 1 ether,
            treasury: address(0x1),
            admin: admin,
            complianceAdmin: admin,
            agent: admin
        });

        // factory is unset (address(0)), so this contract is not factory; onlyFactory must revert.
        vm.expectRevert(EmissionDeployerManager.NotFactory.selector);
        manager.deployEmissionStack(input);
    }
}

