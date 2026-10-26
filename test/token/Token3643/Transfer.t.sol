// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "../../TestSetup.t.sol";
import {IComplianceBase} from "../../../src/interfaces/IComplianceBase.sol";
import {IToken3643} from "../../../src/interfaces/IToken3643.sol";
import {IWalletFreezeComplianceModule} from "../../../src/interfaces/IWalletFreezeComplianceModule.sol";
import {WalletFreezeComplianceModule} from "../../../src/compliance/WalletFreezeComplianceModule.sol";
import {IClaimComplianceModule} from "../../../src/interfaces/IClaimComplianceModule.sol";
import {ClaimComplianceModule} from "../../../src/compliance/ClaimComplianceModule.sol";
import {IdentityFactory} from "../../../src/identity/IdentityFactory.sol";
import {ClaimTopicsRegistry} from "../../../src/claims/ClaimTopicsRegistry.sol";
import {ClaimsRegistry} from "../../../src/claims/ClaimsRegistry.sol";
import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";

contract MockComplianceHooks is IComplianceBase {
    error HookReverted();

    uint256 public transferredCalls;
    bool public shouldRevertOnTransferred;
    address public tokenAddress;

    function setShouldRevertOnTransferred(bool value) external {
        shouldRevertOnTransferred = value;
    }

    function setTokenAddress(address value) external {
        tokenAddress = value;
    }

    function initialize(address, address, address) external {}
    function pause() external {}
    function unpause() external {}
    function setToken(address) external {}
    function addModule(address) external {}
    function removeModule(address) external {}
    function paused() external pure returns (bool) { return false; }
    function token() external view returns (address) { return tokenAddress; }
    function treasury() external pure returns (address) { return address(0); }
    function modules() external pure returns (address[] memory) {
        address[] memory list = new address[](0);
        return list;
    }
    function canTransfer(address, address, uint256) external pure returns (bool allowed) { return true; }
    function transferred(address, address, uint256) external {
        if (shouldRevertOnTransferred) revert HookReverted();
        transferredCalls++;
    }
}

/*//////////////////////////////////////////////////////////////
                            TRANSFER
//////////////////////////////////////////////////////////////*/

contract Token3643TransferTest is TestSetup {
    IWalletFreezeComplianceModule internal freezeModule;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    // Token3643__ReceiverNotActive, Token3643__SenderFrozen, etc.

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        (, , , , , , , , address freezeModuleAddr, ) = tokenFactory.emissions(DEFAULT_EMISSION_ID);
        freezeModule = IWalletFreezeComplianceModule(freezeModuleAddr);
    }

    /*//////////////////////////////////////////////////////////////
                        STATE CHANGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_FromTreasuryToUser_WhenActive() public {
        uint256 amount = 100 ether;
        vm.prank(treasuryWallet);
        emissionToken.transfer(user1, amount);

        assertEq(emissionToken.balanceOf(user1), amount);
        assertEq(emissionToken.balanceOf(treasuryWallet), DEFAULT_INITIAL_SUPPLY - amount);
    }

    /*//////////////////////////////////////////////////////////////
                            NEGATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_ToUnboundWallet_WorksWhenNoTopicsConfigured() public {
        vm.prank(treasuryWallet);
        emissionToken.transfer(user3, 1 ether);

        assertEq(emissionToken.balanceOf(user3), 1 ether);
    }

    function test_Transfer_CallsComplianceTransferredHook() public {
        MockComplianceHooks mockCompliance = new MockComplianceHooks();
        mockCompliance.setTokenAddress(address(emissionToken));

        vm.prank(admin);
        emissionToken.setCompliance(address(mockCompliance));

        vm.prank(treasuryWallet);
        emissionToken.transfer(user1, 1 ether);

        assertEq(mockCompliance.transferredCalls(), 1);
    }

    function test_Transfer_RevertsWhenComplianceTransferredHookReverts() public {
        MockComplianceHooks mockCompliance = new MockComplianceHooks();
        mockCompliance.setTokenAddress(address(emissionToken));

        vm.prank(admin);
        emissionToken.setCompliance(address(mockCompliance));

        mockCompliance.setShouldRevertOnTransferred(true);

        uint256 treasuryBalanceBefore = emissionToken.balanceOf(treasuryWallet);
        uint256 user1BalanceBefore = emissionToken.balanceOf(user1);

        vm.prank(treasuryWallet);
        vm.expectRevert(MockComplianceHooks.HookReverted.selector);
        emissionToken.transfer(user1, 1 ether);

        assertEq(emissionToken.balanceOf(treasuryWallet), treasuryBalanceBefore);
        assertEq(emissionToken.balanceOf(user1), user1BalanceBefore);
    }

    function test_Transfer_RevertsWhenReceiverWalletIsFrozen() public {
        vm.prank(admin);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.FULL);

        vm.prank(treasuryWallet);
        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_ReceiverRestricted.selector, user1));
        emissionToken.transfer(user1, 1 ether);
    }
}

contract Token3643TransferComplianceMatrixTest is TestSetup {
    IWalletFreezeComplianceModule internal freezeModule;
    ClaimComplianceModule internal claimModule;
    IdentityFactory internal identityFactory;
    ClaimsRegistry internal claimsRegistry;
    ClaimTopicsRegistry internal topicsRegistry;
    TopicCatalog internal topicCatalog;

    uint256 internal constant TOPIC_KYC = 1;
    uint256 internal constant TRANSFER_AMOUNT = 10 ether;

    function setUp() public override {
        super.setUp();

        (
            ,
            ,
            ,
            address identityFactoryAddr,
            address claimsRegistryAddr,
            address topicsRegistryAddr,
            ,
            address claimModuleAddr,
            address freezeModuleAddr,
            
        ) = tokenFactory.emissions(DEFAULT_EMISSION_ID);

        identityFactory = IdentityFactory(identityFactoryAddr);
        claimsRegistry = ClaimsRegistry(claimsRegistryAddr);
        topicsRegistry = ClaimTopicsRegistry(topicsRegistryAddr);
        claimModule = ClaimComplianceModule(claimModuleAddr);
        freezeModule = IWalletFreezeComplianceModule(freezeModuleAddr);
        topicCatalog = TopicCatalog(tokenFactory.topicCatalog());

        vm.prank(admin);
        topicCatalog.setTopic(TOPIC_KYC, "KYC", "Know your customer", true);

        uint256 amountPerUser = 100 ether;
        vm.prank(treasuryWallet);
        emissionToken.transfer(user1, amountPerUser);
        vm.prank(treasuryWallet);
        emissionToken.transfer(user2, amountPerUser);
    }

    function _enableKycRequirement() internal {
        vm.prank(admin);
        topicsRegistry.addTopic(TOPIC_KYC);
    }

    /*//////////////////////////////////////////////////////////////
                                KYC MATRIX
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_UserToUser_Reverts_WhenBothWithoutKYC() public {
        _enableKycRequirement();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IClaimComplianceModule.ClaimModule_SenderRequirementsNotSatisfied.selector, user1));
        emissionToken.transfer(user2, TRANSFER_AMOUNT);
    }

    function test_Transfer_UserToUser_Reverts_WhenOnlySenderHasKYC() public {
        _enableKycRequirement();

        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("matrix-u1-kyc-only"), user1);
        emissionRegistry.setIdentity(user1, id1);
        claimsRegistry.setClaim(
            id1, TOPIC_KYC, keccak256("claim-matrix-u1-kyc-only"), uint64(block.timestamp + 1 days)
        );
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IClaimComplianceModule.ClaimModule_ReceiverRequirementsNotSatisfied.selector, user2));
        emissionToken.transfer(user2, TRANSFER_AMOUNT);
    }

    function test_Transfer_UserToUser_Reverts_WhenOnlyReceiverHasKYC() public {
        _enableKycRequirement();

        vm.startPrank(admin);
        address id2 = identityFactory.createIdentity(keccak256("matrix-u2-kyc-only"), user2);
        emissionRegistry.setIdentity(user2, id2);
        claimsRegistry.setClaim(
            id2, TOPIC_KYC, keccak256("claim-matrix-u2-kyc-only"), uint64(block.timestamp + 1 days)
        );
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IClaimComplianceModule.ClaimModule_SenderRequirementsNotSatisfied.selector, user1));
        emissionToken.transfer(user2, TRANSFER_AMOUNT);
    }

    function test_Transfer_UserToUser_Succeeds_WhenBothHaveKYC() public {
        _enableKycRequirement();

        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("matrix-u1-kyc-both"), user1);
        address id2 = identityFactory.createIdentity(keccak256("matrix-u2-kyc-both"), user2);
        emissionRegistry.setIdentity(user1, id1);
        emissionRegistry.setIdentity(user2, id2);
        claimsRegistry.setClaim(id1, TOPIC_KYC, keccak256("claim-matrix-u1-kyc-both"), uint64(block.timestamp + 1 days));
        claimsRegistry.setClaim(id2, TOPIC_KYC, keccak256("claim-matrix-u2-kyc-both"), uint64(block.timestamp + 1 days));
        vm.stopPrank();

        uint256 user1BalanceBefore = emissionToken.balanceOf(user1);
        uint256 user2BalanceBefore = emissionToken.balanceOf(user2);

        vm.prank(user1);
        emissionToken.transfer(user2, TRANSFER_AMOUNT);

        assertEq(emissionToken.balanceOf(user1), user1BalanceBefore - TRANSFER_AMOUNT);
        assertEq(emissionToken.balanceOf(user2), user2BalanceBefore + TRANSFER_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                FREEZE MATRIX
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_UserToUser_Reverts_WhenSenderWalletFrozen() public {
        vm.prank(admin);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.FULL);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        emissionToken.transfer(user2, TRANSFER_AMOUNT);
    }

    function test_Transfer_UserToUser_Reverts_WhenSenderIdentityFrozen() public {
        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("matrix-freeze-u1"), user1);
        emissionRegistry.setIdentity(user1, id1);
        freezeModule.setIdentityMode(id1, IWalletFreezeComplianceModule.FreezeMode.FULL);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        emissionToken.transfer(user2, TRANSFER_AMOUNT);
    }

    function test_Transfer_UserToUser_RespectsSendOnlyMode() public {
        vm.prank(admin);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.SEND_ONLY);

        uint256 user2BalanceBefore = emissionToken.balanceOf(user2);

        vm.prank(user1);
        emissionToken.transfer(user2, TRANSFER_AMOUNT);

        assertEq(emissionToken.balanceOf(user2), user2BalanceBefore + TRANSFER_AMOUNT);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_ReceiverRestricted.selector, user1));
        emissionToken.transfer(user1, TRANSFER_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                MIXED SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_UserToTreasury_Allowed_WhenKYCAndOnlyToTreasuryFreeze() public {
        _enableKycRequirement();

        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("matrix-mixed-u1"), user1);
        emissionRegistry.setIdentity(user1, id1);
        claimsRegistry.setClaim(
            id1, TOPIC_KYC, keccak256("claim-matrix-mixed-u1"), uint64(block.timestamp + 1 days)
        );
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.ONLY_TO_TREASURY);
        vm.stopPrank();

        uint256 treasuryBefore = emissionToken.balanceOf(treasuryWallet);

        vm.prank(user1);
        emissionToken.transfer(treasuryWallet, TRANSFER_AMOUNT);

        assertEq(emissionToken.balanceOf(treasuryWallet), treasuryBefore + TRANSFER_AMOUNT);
    }

    function test_Transfer_UserToUser_Reverts_WhenKYCButOnlyToTreasuryFreeze() public {
        _enableKycRequirement();

        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("matrix-mixed-u1-ott"), user1);
        address id2 = identityFactory.createIdentity(keccak256("matrix-mixed-u2-ott"), user2);
        emissionRegistry.setIdentity(user1, id1);
        emissionRegistry.setIdentity(user2, id2);
        claimsRegistry.setClaim(
            id1, TOPIC_KYC, keccak256("claim-matrix-mixed-u1-ott"), uint64(block.timestamp + 1 days)
        );
        claimsRegistry.setClaim(
            id2, TOPIC_KYC, keccak256("claim-matrix-mixed-u2-ott"), uint64(block.timestamp + 1 days)
        );
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.ONLY_TO_TREASURY);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        emissionToken.transfer(user2, TRANSFER_AMOUNT);
    }
}
