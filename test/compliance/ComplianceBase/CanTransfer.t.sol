// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ComplianceBase} from "../../../src/compliance/ComplianceBase.sol";
import {IComplianceBase} from "../../../src/interfaces/IComplianceBase.sol";
import {IComplianceModule} from "../../../src/interfaces/IComplianceModule.sol";

contract MockModuleReturnsFalse is IComplianceModule, ERC165 {
    function canTransfer(address, address, uint256) external pure returns (bool) {
        return false;
    }
    function transferred(address, address, uint256) external pure {}

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IComplianceModule).interfaceId
            || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }
}

/*//////////////////////////////////////////////////////////////
                    CAN TRANSFER / TRANSFERRED
//////////////////////////////////////////////////////////////*/

contract ComplianceBaseCanTransferTest is TestSetup {

    function test_CanTransfer_WhenNoModules_ReturnsTrue() public view {
        assertTrue(emissionCompliance.canTransfer(user1, user2, 1 ether));
    }

    function test_CanTransfer_WhenPaused_RevertsWithCompliancePaused() public {
        vm.prank(admin);
        emissionCompliance.pause();
        vm.expectRevert(IComplianceBase.CompliancePaused.selector);
        emissionCompliance.canTransfer(user1, user2, 1 ether);
    }

    function test_CanTransfer_WhenModuleReturnsFalse_RevertsWithModuleRejected() public {
        MockModuleReturnsFalse rejectingModule = new MockModuleReturnsFalse();
        vm.prank(admin);
        emissionCompliance.addModule(address(rejectingModule));

        vm.expectRevert(abi.encodeWithSelector(IComplianceBase.ModuleRejected.selector, address(rejectingModule)));
        emissionCompliance.canTransfer(user1, user2, 1 ether);
    }

    function test_SetToken_RevertsWhenAlreadySet() public {
        vm.prank(admin);
        vm.expectRevert(IComplianceBase.TokenAlreadySet.selector);
        emissionCompliance.setToken(user3);
    }

    function test_Transferred_RevertsWhenCallerIsNotToken() public {
        vm.prank(user1);
        vm.expectRevert(IComplianceBase.NotTokenCaller.selector);
        emissionCompliance.transferred(user1, user2, 1 ether);
    }

    function test_Transferred_RevertsWhenPausedEvenForTokenCaller() public {
        vm.prank(admin);
        emissionCompliance.pause();

        vm.prank(address(emissionToken));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        emissionCompliance.transferred(user1, user2, 1 ether);
    }

    function test_PauseAndUnpause_Flow() public {
        vm.prank(admin);
        emissionCompliance.pause();
        assertTrue(emissionCompliance.paused());

        vm.prank(admin);
        emissionCompliance.unpause();
        assertFalse(emissionCompliance.paused());
    }

    function test_SetToken_RevertsWhenZeroAddress() public {
        ComplianceBase impl = new ComplianceBase();
        bytes memory initData = abi.encodeCall(ComplianceBase.initialize, (admin, admin, treasuryWallet));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        ComplianceBase freshCompliance = ComplianceBase(address(proxy));

        vm.prank(admin);
        vm.expectRevert(IComplianceBase.ZeroAddress.selector);
        freshCompliance.setToken(address(0));
    }
}
