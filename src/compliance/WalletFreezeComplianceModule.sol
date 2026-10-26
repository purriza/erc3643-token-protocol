// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IComplianceModule} from "../interfaces/IComplianceModule.sol";
import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {IWalletFreezeComplianceModule} from "../interfaces/IWalletFreezeComplianceModule.sol";

/**
 * @title WalletFreezeComplianceModule
 * @notice Compliance module that enforces wallet and identity freezes.
 */
contract WalletFreezeComplianceModule is IWalletFreezeComplianceModule, AccessControl {
    
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to execute admin operations (manage wallet and identity freeze)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Identity registry used to resolve wallet -> identity binding.
    IIdentityRegistry public immutable identityRegistry;

    /// @notice Treasury address used by ONLY_TO_TREASURY mode.
    address public immutable treasury;

    /// @notice Explicit freeze modes by wallet.
    mapping(address wallet => FreezeMode mode) public walletMode;

    /// @notice Explicit freeze modes by identity.
    mapping(address identity => FreezeMode mode) public identityMode;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a wallet/identity freeze module bound to one emission registry.
     * @param identityRegistry_ Identity registry instance of the emission.
     * @param treasury_ Emission treasury address.
     * @param admin_ Emission admin address.
     * @param complianceAdmin_ Emission compliance admin address.
     */
    constructor(IIdentityRegistry identityRegistry_, address treasury_, address admin_, address complianceAdmin_) {
        if (
            address(identityRegistry_) == address(0) || treasury_ == address(0) || admin_ == address(0)
                || complianceAdmin_ == address(0)
        ) {
            revert ZeroAddress();
        }

        identityRegistry = identityRegistry_;
        treasury = treasury_;

        // Grant roles to the admin and compliance admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, complianceAdmin_);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IWalletFreezeComplianceModule
    function setWalletMode(address wallet, FreezeMode mode) external onlyRole(ADMIN_ROLE) {
        if (wallet == address(0)) revert ZeroAddress();

        FreezeMode previousMode = walletMode[wallet];
        walletMode[wallet] = mode;
        emit WalletFreezeModeSet(wallet, previousMode, mode);
    }

    /// @inheritdoc IWalletFreezeComplianceModule
    function setWalletModes(address[] calldata wallets, FreezeMode[] calldata modes) external onlyRole(ADMIN_ROLE) {
        uint256 length = wallets.length;
        if (length != modes.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < length; i++) {
            address wallet = wallets[i];
            if (wallet == address(0)) revert ZeroAddress();

            FreezeMode mode = modes[i];
            FreezeMode previousMode = walletMode[wallet];
            walletMode[wallet] = mode;
            emit WalletFreezeModeSet(wallet, previousMode, mode);
        }
    }

    /// @inheritdoc IWalletFreezeComplianceModule
    function setIdentityMode(address identity, FreezeMode mode) external onlyRole(ADMIN_ROLE) {
        if (identity == address(0)) revert ZeroAddress();

        FreezeMode previousMode = identityMode[identity];
        identityMode[identity] = mode;
        emit IdentityFreezeModeSet(identity, previousMode, mode);
    }

    /// @inheritdoc IWalletFreezeComplianceModule
    function setIdentityModes(address[] calldata identities, FreezeMode[] calldata modes)
        external
        onlyRole(ADMIN_ROLE)
    {
        uint256 length = identities.length;
        if (length != modes.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < length; i++) {
            address identity = identities[i];
            if (identity == address(0)) revert ZeroAddress();

            FreezeMode mode = modes[i];
            FreezeMode previousMode = identityMode[identity];
            identityMode[identity] = mode;
            emit IdentityFreezeModeSet(identity, previousMode, mode);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComplianceModule
    /// @dev Reverts with FreezeModule_SenderRestricted or FreezeModule_ReceiverRestricted instead of returning false.
    function canTransfer(address from, address to, uint256) external view returns (bool allowed) {
        if (from != address(0) && !_isDirectionAllowed(from, to, true)) {
            revert FreezeModule_SenderRestricted(from);
        }
        if (to != address(0) && !_isDirectionAllowed(to, from, false)) {
            revert FreezeModule_ReceiverRestricted(to);
        }

        return true;
    }

    /// @inheritdoc IComplianceModule
    function transferred(address from, address to, uint256 amount) external pure {
        (from, to, amount);
    }

    /// @inheritdoc AccessControl
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return interfaceId == type(IComplianceModule).interfaceId
            || interfaceId == type(IWalletFreezeComplianceModule).interfaceId
            || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns effective freeze mode combining wallet and identity modes.
    function _effectiveMode(address wallet) internal view returns (FreezeMode) {
        FreezeMode mode = walletMode[wallet];
        address identity = identityRegistry.identityOf(wallet);
        if (identity == address(0)) {
            return mode;
        }

        FreezeMode identityMode_ = identityMode[identity];
        if (_modePriority(identityMode_) > _modePriority(mode)) {
            return identityMode_;
        }

        return mode;
    }

    /// @notice Returns whether transfer direction for a participant is allowed by its freeze mode.
    /// @param participant Wallet being evaluated.
    /// @param counterparty Opposite transfer side (to for send, from for receive).
    /// @param isSender True when evaluating sender side, false for receiver side.
    function _isDirectionAllowed(address participant, address counterparty, bool isSender) internal view returns (bool) {
        FreezeMode mode = _effectiveMode(participant);

        if (mode == FreezeMode.NONE) return true;
        if (mode == FreezeMode.FULL) return false;

        if (mode == FreezeMode.SEND_ONLY) {
            return isSender;
        }

        if (mode == FreezeMode.RECEIVE_ONLY) {
            return !isSender;
        }

        // ONLY_TO_TREASURY
        if (isSender) {
            return counterparty == treasury;
        }

        return true;
    }

    /// @notice Returns explicit priority used to resolve wallet/identity mode conflicts.
    function _modePriority(FreezeMode mode) internal pure returns (uint8) {
        if (mode == FreezeMode.FULL) return 4;
        if (mode == FreezeMode.ONLY_TO_TREASURY) return 3;
        if (mode == FreezeMode.SEND_ONLY || mode == FreezeMode.RECEIVE_ONLY) return 2;
        return 1; // NONE
    }
}
