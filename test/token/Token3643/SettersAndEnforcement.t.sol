// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {TestSetup} from "../../TestSetup.t.sol";

import {Token3643} from "../../../src/token/Token3643.sol";
import {IToken3643} from "../../../src/interfaces/IToken3643.sol";
import {IComplianceBase} from "../../../src/interfaces/IComplianceBase.sol";

contract MockComplianceDecision is IComplianceBase {
    bool internal allowed;

    constructor(bool allowed_) {
        allowed = allowed_;
    }

    function setAllowed(bool allowed_) external {
        allowed = allowed_;
    }

    function initialize(address, address, address) external {}
    function pause() external {}
    function unpause() external {}
    function setToken(address) external {}
    function addModule(address) external {}
    function removeModule(address) external {}
    function paused() external pure returns (bool) { return false; }
    function token() external pure returns (address) { return address(0); }
    function treasury() external pure returns (address) { return address(0); }
    function modules() external pure returns (address[] memory list) { list = new address[](0); }
    function canTransfer(address, address, uint256) external view returns (bool) { return allowed; }
    function transferred(address, address, uint256) external {}
}

contract Token3643Harness is Token3643 {
    constructor(
        string memory name_,
        string memory symbol_,
        address registry_,
        address compliance_,
        address treasury_,
        address admin_,
        address complianceAdmin_,
        address agent_,
        uint256 maxSupply_
    ) Token3643(name_, symbol_, registry_, compliance_, treasury_, admin_, complianceAdmin_, agent_, maxSupply_) {}

    function mintForTest(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burnForTest(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function enforceComplianceForTest(address from, address to, uint256 amount) external view {
        _enforceCompliance(from, to, amount);
    }
}

contract Token3643SettersAndEnforcementTest is TestSetup {
    function test_SetRegistry_RevertsWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IToken3643.ZeroAddress.selector);
        emissionToken.setRegistry(address(0));
    }

    function test_SetRegistry_UpdatesRegistry() public {
        vm.prank(admin);
        emissionToken.setRegistry(user3);
        assertEq(address(emissionToken.registry()), user3);
    }

    function test_SetCompliance_RevertsWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IToken3643.ZeroAddress.selector);
        emissionToken.setCompliance(address(0));
    }

    function test_SetCompliance_RevertsWhenComplianceRejects() public {
        MockComplianceDecision rejecting = new MockComplianceDecision(false);
        vm.prank(admin);
        vm.expectRevert(IToken3643.ComplianceRejected.selector);
        emissionToken.setCompliance(address(rejecting));
    }

    function test_SetCompliance_UpdatesComplianceWhenAllowed() public {
        MockComplianceDecision allowing = new MockComplianceDecision(true);
        vm.prank(admin);
        emissionToken.setCompliance(address(allowing));
        assertEq(address(emissionToken.compliance()), address(allowing));
    }

    function test_SetTreasury_RevertsWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IToken3643.ZeroAddress.selector);
        emissionToken.setTreasury(address(0));
    }

    function test_SetTreasury_RevertsWhenComplianceRejects() public {
        MockComplianceDecision allowing = new MockComplianceDecision(true);
        vm.prank(admin);
        emissionToken.setCompliance(address(allowing));

        allowing.setAllowed(false);

        vm.prank(admin);
        vm.expectRevert(IToken3643.ComplianceRejected.selector);
        emissionToken.setTreasury(user1);
    }

    function test_SetTreasury_UpdatesTreasuryWhenAllowed() public {
        vm.prank(admin);
        emissionToken.setTreasury(user1);
        assertEq(emissionToken.treasury(), user1);
    }

    function test_EnforceCompliance_RevertsWhenMintToNonTreasury() public {
        MockComplianceDecision allowing = new MockComplianceDecision(true);
        Token3643Harness harness = new Token3643Harness(
            "Harness", "HRS", address(emissionRegistry), address(allowing), treasuryWallet, admin, admin, admin, 0
        );

        vm.expectRevert(abi.encodeWithSelector(IToken3643.MintToNonTreasury.selector, user1));
        harness.mintForTest(user1, 1 ether);
    }

    function test_EnforceCompliance_RevertsWhenMintComplianceRejects() public {
        MockComplianceDecision rejecting = new MockComplianceDecision(false);
        vm.expectRevert(IToken3643.ComplianceRejected.selector);
        new Token3643Harness(
            "Harness", "HRS", address(emissionRegistry), address(rejecting), treasuryWallet, admin, admin, admin, 1 ether
        );
    }

    function test_EnforceCompliance_AllowsBurnPath() public {
        MockComplianceDecision allowing = new MockComplianceDecision(true);
        Token3643Harness harness = new Token3643Harness(
            "Harness", "HRS", address(emissionRegistry), address(allowing), treasuryWallet, admin, admin, admin, 1 ether
        );

        harness.burnForTest(treasuryWallet, 1 ether);
        assertEq(harness.totalSupply(), 0);
    }

    function test_EnforceCompliance_RevertsWhenBothFromAndToAreZero() public {
        MockComplianceDecision allowing = new MockComplianceDecision(true);
        Token3643Harness harness = new Token3643Harness(
            "Harness", "HRS", address(emissionRegistry), address(allowing), treasuryWallet, admin, admin, admin, 0
        );

        vm.expectRevert(IToken3643.ComplianceRejected.selector);
        harness.enforceComplianceForTest(address(0), address(0), 0);
    }

    /// @dev Covers the negative branch of _enforceCompliance normal transfer path when compliance rejects.
    function test_EnforceCompliance_TransferRevertsWhenComplianceRejects() public {
        MockComplianceDecision decision = new MockComplianceDecision(true);

        // First set a compliant module so the initial validation in setCompliance succeeds.
        vm.prank(admin);
        emissionToken.setCompliance(address(decision));

        // Then flip the decision to false to make the transfer path fail canTransfer.
        decision.setAllowed(false);

        vm.prank(treasuryWallet);
        vm.expectRevert(IToken3643.ComplianceRejected.selector);
        emissionToken.transfer(user1, 1 ether);
    }

    /// @dev Covers _enforceCompliance normal transfer success path (return after canTransfer true) for line/branch coverage.
    function test_EnforceCompliance_TransferSucceedsWhenComplianceReturnsTrue() public {
        MockComplianceDecision allowing = new MockComplianceDecision(true);
        Token3643Harness harness = new Token3643Harness(
            "Harness", "HRS", address(emissionRegistry), address(allowing), treasuryWallet, admin, admin, admin, 1 ether
        );

        vm.prank(treasuryWallet);
        bool ok = harness.transfer(user1, 1 ether);
        assertTrue(ok);
        assertEq(harness.balanceOf(user1), 1 ether);
    }

    /// @dev Same success path on emissionToken (same contract instance as coverage target) to hit line 149 / branch.
    function test_EnforceCompliance_EmissionTokenTransferSucceedsWithAllowingMock() public {
        MockComplianceDecision allowing = new MockComplianceDecision(true);
        vm.prank(admin);
        emissionToken.setCompliance(address(allowing));

        vm.prank(treasuryWallet);
        bool ok = emissionToken.transfer(user1, 1 ether);
        assertTrue(ok);
        assertEq(emissionToken.balanceOf(user1), 1 ether);
    }

    function test_Burn_BurnsFromCallerBalance() public {
        uint256 amount = 123 ether;
        uint256 supplyBefore = emissionToken.totalSupply();
        uint256 treasuryBefore = emissionToken.balanceOf(treasuryWallet);

        vm.prank(treasuryWallet);
        emissionToken.burn(amount);

        assertEq(emissionToken.totalSupply(), supplyBefore - amount);
        assertEq(emissionToken.balanceOf(treasuryWallet), treasuryBefore - amount);
    }

    function test_Burn_RevertsWhenAmountExceedsBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        emissionToken.burn(1 ether);
    }
}
