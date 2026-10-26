// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {TestSetup} from "../../TestSetup.t.sol";

import {IWalletFreezeComplianceModule} from "../../../src/interfaces/IWalletFreezeComplianceModule.sol";
import {IdentityFactory} from "../../../src/identity/IdentityFactory.sol";
import {WalletFreezeComplianceModule} from "../../../src/compliance/WalletFreezeComplianceModule.sol";
import {IIdentityRegistry} from "../../../src/interfaces/IIdentityRegistry.sol";

contract WalletFreezeComplianceModuleCanTransferTest is TestSetup {
    IWalletFreezeComplianceModule internal freezeModule;
    IdentityFactory internal identityFactory;

    function setUp() public override {
        super.setUp();

        (, , , address identityFactoryAddr, , , , , address freezeModuleAddr, ) = tokenFactory.emissions(DEFAULT_EMISSION_ID);
        freezeModule = IWalletFreezeComplianceModule(freezeModuleAddr);
        identityFactory = IdentityFactory(identityFactoryAddr);
    }

    function test_CanTransfer_TrueWhenNoWalletOrIdentityFrozen() public view {
        assertTrue(freezeModule.canTransfer(user1, user2, 1 ether));
    }

    function test_CanTransfer_FalseWhenSenderWalletFrozen() public {
        vm.prank(admin);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.FULL);

        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        freezeModule.canTransfer(user1, user2, 1 ether);
    }

    function test_CanTransfer_FalseWhenReceiverWalletFrozen() public {
        vm.prank(admin);
        freezeModule.setWalletMode(user2, IWalletFreezeComplianceModule.FreezeMode.FULL);

        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_ReceiverRestricted.selector, user2));
        freezeModule.canTransfer(user1, user2, 1 ether);
    }

    function test_CanTransfer_FalseWhenSenderIdentityFrozen() public {
        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("freeze-u1"), user1);
        emissionRegistry.setIdentity(user1, id1);
        freezeModule.setIdentityMode(id1, IWalletFreezeComplianceModule.FreezeMode.FULL);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        freezeModule.canTransfer(user1, user2, 1 ether);
    }

    function test_SetWalletMode_RevertsWhenNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        freezeModule.setWalletMode(user2, IWalletFreezeComplianceModule.FreezeMode.FULL);
    }

    function test_SetWalletModes_RevertsWhenArrayLengthMismatch() public {
        address[] memory wallets = new address[](2);
        IWalletFreezeComplianceModule.FreezeMode[] memory modes = new IWalletFreezeComplianceModule.FreezeMode[](1);
        wallets[0] = user1;
        wallets[1] = user2;
        modes[0] = IWalletFreezeComplianceModule.FreezeMode.SEND_ONLY;

        vm.prank(admin);
        vm.expectRevert(IWalletFreezeComplianceModule.InvalidArrayLength.selector);
        freezeModule.setWalletModes(wallets, modes);
    }

    function test_CanTransfer_SendOnlyMode() public {
        vm.prank(admin);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.SEND_ONLY);

        assertTrue(freezeModule.canTransfer(user1, user2, 1 ether));
        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_ReceiverRestricted.selector, user1));
        freezeModule.canTransfer(user2, user1, 1 ether);
    }

    function test_CanTransfer_ReceiveOnlyMode() public {
        vm.prank(admin);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.RECEIVE_ONLY);

        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        freezeModule.canTransfer(user1, user2, 1 ether);
        assertTrue(freezeModule.canTransfer(user2, user1, 1 ether));
    }

    function test_CanTransfer_OnlyToTreasuryMode() public {
        vm.prank(admin);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.ONLY_TO_TREASURY);

        assertTrue(freezeModule.canTransfer(user1, treasuryWallet, 1 ether));
        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        freezeModule.canTransfer(user1, user2, 1 ether);
    }

    function test_CanTransfer_Priority_FullWinsOverOnlyToTreasury() public {
        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("freeze-priority-full"), user1);
        emissionRegistry.setIdentity(user1, id1);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.ONLY_TO_TREASURY);
        freezeModule.setIdentityMode(id1, IWalletFreezeComplianceModule.FreezeMode.FULL);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        freezeModule.canTransfer(user1, treasuryWallet, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_ReceiverRestricted.selector, user1));
        freezeModule.canTransfer(user2, user1, 1 ether);
    }

    function test_CanTransfer_Priority_OnlyToTreasuryWinsOverSendOnly() public {
        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("freeze-priority-ott"), user1);
        emissionRegistry.setIdentity(user1, id1);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.SEND_ONLY);
        freezeModule.setIdentityMode(id1, IWalletFreezeComplianceModule.FreezeMode.ONLY_TO_TREASURY);
        vm.stopPrank();

        assertTrue(freezeModule.canTransfer(user1, treasuryWallet, 1 ether));
        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        freezeModule.canTransfer(user1, user2, 1 ether);
    }

    function test_SetWalletModes_Success() public {
        address[] memory wallets = new address[](2);
        IWalletFreezeComplianceModule.FreezeMode[] memory modes = new IWalletFreezeComplianceModule.FreezeMode[](2);
        wallets[0] = user1;
        wallets[1] = user2;
        modes[0] = IWalletFreezeComplianceModule.FreezeMode.SEND_ONLY;
        modes[1] = IWalletFreezeComplianceModule.FreezeMode.RECEIVE_ONLY;

        vm.prank(admin);
        freezeModule.setWalletModes(wallets, modes);

        assertEq(uint8(freezeModule.walletMode(user1)), uint8(IWalletFreezeComplianceModule.FreezeMode.SEND_ONLY));
        assertEq(uint8(freezeModule.walletMode(user2)), uint8(IWalletFreezeComplianceModule.FreezeMode.RECEIVE_ONLY));
    }

    function test_SetWalletModes_RevertsWhenAnyWalletIsZero() public {
        address[] memory wallets = new address[](1);
        IWalletFreezeComplianceModule.FreezeMode[] memory modes = new IWalletFreezeComplianceModule.FreezeMode[](1);
        wallets[0] = address(0);
        modes[0] = IWalletFreezeComplianceModule.FreezeMode.FULL;

        vm.prank(admin);
        vm.expectRevert(IWalletFreezeComplianceModule.ZeroAddress.selector);
        freezeModule.setWalletModes(wallets, modes);
    }

    function test_SetIdentityModes_RevertsWhenArrayLengthMismatch() public {
        address[] memory identities = new address[](2);
        IWalletFreezeComplianceModule.FreezeMode[] memory modes = new IWalletFreezeComplianceModule.FreezeMode[](1);
        identities[0] = makeAddr("id1");
        identities[1] = makeAddr("id2");
        modes[0] = IWalletFreezeComplianceModule.FreezeMode.FULL;

        vm.prank(admin);
        vm.expectRevert(IWalletFreezeComplianceModule.InvalidArrayLength.selector);
        freezeModule.setIdentityModes(identities, modes);
    }

    function test_SetIdentityModes_RevertsWhenAnyIdentityIsZero() public {
        address[] memory identities = new address[](1);
        IWalletFreezeComplianceModule.FreezeMode[] memory modes = new IWalletFreezeComplianceModule.FreezeMode[](1);
        identities[0] = address(0);
        modes[0] = IWalletFreezeComplianceModule.FreezeMode.FULL;

        vm.prank(admin);
        vm.expectRevert(IWalletFreezeComplianceModule.ZeroAddress.selector);
        freezeModule.setIdentityModes(identities, modes);
    }

    function test_SetIdentityModes_Success() public {
        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("freeze-batch-u1"), user1);
        address id2 = identityFactory.createIdentity(keccak256("freeze-batch-u2"), user2);
        emissionRegistry.setIdentity(user1, id1);
        emissionRegistry.setIdentity(user2, id2);
        vm.stopPrank();

        address[] memory identities = new address[](2);
        IWalletFreezeComplianceModule.FreezeMode[] memory modes = new IWalletFreezeComplianceModule.FreezeMode[](2);
        identities[0] = id1;
        identities[1] = id2;
        modes[0] = IWalletFreezeComplianceModule.FreezeMode.ONLY_TO_TREASURY;
        modes[1] = IWalletFreezeComplianceModule.FreezeMode.FULL;

        vm.prank(admin);
        freezeModule.setIdentityModes(identities, modes);

        assertEq(
            uint8(freezeModule.identityMode(id1)), uint8(IWalletFreezeComplianceModule.FreezeMode.ONLY_TO_TREASURY)
        );
        assertEq(uint8(freezeModule.identityMode(id2)), uint8(IWalletFreezeComplianceModule.FreezeMode.FULL));
    }

    function test_CanTransfer_OnlyToTreasuryOnReceiverSide_AllowsReceiving() public {
        vm.prank(admin);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.ONLY_TO_TREASURY);

        assertTrue(freezeModule.canTransfer(user2, user1, 1 ether));
    }

    function test_Constructor_RevertsWhenAnyCriticalAddressIsZero() public {
        vm.expectRevert(IWalletFreezeComplianceModule.ZeroAddress.selector);
        new WalletFreezeComplianceModule(IIdentityRegistry(address(0)), treasuryWallet, admin, admin);

        vm.expectRevert(IWalletFreezeComplianceModule.ZeroAddress.selector);
        new WalletFreezeComplianceModule(emissionRegistry, address(0), admin, admin);

        vm.expectRevert(IWalletFreezeComplianceModule.ZeroAddress.selector);
        new WalletFreezeComplianceModule(emissionRegistry, treasuryWallet, address(0), admin);

        vm.expectRevert(IWalletFreezeComplianceModule.ZeroAddress.selector);
        new WalletFreezeComplianceModule(emissionRegistry, treasuryWallet, admin, address(0));
    }

    function test_SetWalletMode_RevertsWhenWalletIsZero() public {
        vm.prank(admin);
        vm.expectRevert(IWalletFreezeComplianceModule.ZeroAddress.selector);
        freezeModule.setWalletMode(address(0), IWalletFreezeComplianceModule.FreezeMode.FULL);
    }

    function test_SetIdentityMode_RevertsWhenIdentityIsZero() public {
        vm.prank(admin);
        vm.expectRevert(IWalletFreezeComplianceModule.ZeroAddress.selector);
        freezeModule.setIdentityMode(address(0), IWalletFreezeComplianceModule.FreezeMode.FULL);
    }

    function test_CanTransfer_Priority_UsesWalletModeWhenIdentityModeIsLessRestrictive() public {
        vm.startPrank(admin);
        address id1 = identityFactory.createIdentity(keccak256("freeze-wallet-wins"), user1);
        emissionRegistry.setIdentity(user1, id1);
        freezeModule.setWalletMode(user1, IWalletFreezeComplianceModule.FreezeMode.FULL);
        freezeModule.setIdentityMode(id1, IWalletFreezeComplianceModule.FreezeMode.SEND_ONLY);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IWalletFreezeComplianceModule.FreezeModule_SenderRestricted.selector, user1));
        freezeModule.canTransfer(user1, user2, 1 ether);
    }
}
