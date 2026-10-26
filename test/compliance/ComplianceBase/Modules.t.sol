// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {ComplianceBase} from "../../../src/compliance/ComplianceBase.sol";
import {IComplianceModule} from "../../../src/interfaces/IComplianceModule.sol";
import {IComplianceBase} from "../../../src/interfaces/IComplianceBase.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/*//////////////////////////////////////////////////////////////
                    MODULES (ADD / REMOVE)
//////////////////////////////////////////////////////////////*/

contract MockComplianceModule is IComplianceModule, ERC165 {
    function canTransfer(address, address, uint256) external pure returns (bool) {
        return true;
    }
    function transferred(address, address, uint256) external pure {}

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IComplianceModule).interfaceId
            || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }
}

contract NonCompliantModule {
    function ping() external pure returns (bool) {
        return true;
    }
}

contract ComplianceBaseModulesTest is TestSetup {

    function test_AddModule_Success() public {
        MockComplianceModule module = new MockComplianceModule();
        vm.prank(admin);
        emissionCompliance.addModule(address(module));
        address[] memory modules = emissionCompliance.modules();
        // Factory installs ClaimComplianceModule and WalletFreezeComplianceModule by default.
        assertEq(modules.length, 3);
        assertEq(modules[2], address(module));
    }

    function test_AddModule_RevertsWhenNotAdmin() public {
        MockComplianceModule module = new MockComplianceModule();
        vm.prank(user1); // user1 does not have ADMIN_ROLE
        vm.expectRevert();
        emissionCompliance.addModule(address(module));
    }

    function test_RemoveModule_Success() public {
        MockComplianceModule module = new MockComplianceModule();
        vm.startPrank(admin);
        emissionCompliance.addModule(address(module));
        emissionCompliance.removeModule(address(module));
        vm.stopPrank();
        address[] memory modules = emissionCompliance.modules();
        // Only default factory modules should remain after removal.
        assertEq(modules.length, 2);
    }

    function test_AddModule_RevertsWhenModuleDoesNotSupportIComplianceModule() public {
        NonCompliantModule module = new NonCompliantModule();
        vm.prank(admin);
        vm.expectRevert(IComplianceBase.InvalidModule.selector);
        emissionCompliance.addModule(address(module));
    }

    function test_AddModule_RevertsWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IComplianceBase.ZeroAddress.selector);
        emissionCompliance.addModule(address(0));
    }

    function test_AddModule_RevertsWhenAlreadyAdded() public {
        MockComplianceModule module = new MockComplianceModule();
        vm.startPrank(admin);
        emissionCompliance.addModule(address(module));
        vm.expectRevert(IComplianceBase.ModuleAlreadyAdded.selector);
        emissionCompliance.addModule(address(module));
        vm.stopPrank();
    }

    function test_RemoveModule_RevertsWhenNotFound() public {
        MockComplianceModule module = new MockComplianceModule();
        vm.prank(admin);
        vm.expectRevert(IComplianceBase.ModuleNotFound.selector);
        emissionCompliance.removeModule(address(module));
    }

    function test_RemoveModule_SwapsWhenRemovingNonLastModule() public {
        MockComplianceModule moduleA = new MockComplianceModule();
        MockComplianceModule moduleB = new MockComplianceModule();

        vm.startPrank(admin);
        emissionCompliance.addModule(address(moduleA));
        emissionCompliance.addModule(address(moduleB));
        emissionCompliance.removeModule(address(moduleA));
        vm.stopPrank();

        address[] memory modules = emissionCompliance.modules();
        assertEq(modules.length, 3);
        assertEq(modules[2], address(moduleB));
    }

    function test_RemoveModule_RevertsWhenMappingIsInconsistent() public {
        address ghostModule = address(0xBEEF);
        bytes32 slot = keccak256(abi.encode(ghostModule, uint256(3)));
        vm.store(address(emissionCompliance), slot, bytes32(uint256(1)));

        vm.prank(admin);
        vm.expectRevert(IComplianceBase.ModuleNotFound.selector);
        emissionCompliance.removeModule(ghostModule);
    }
}
