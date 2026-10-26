// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IComplianceModule} from "./IComplianceModule.sol";
import {IIdentityRegistry} from "./IIdentityRegistry.sol";

/**
 * @title IWalletFreezeComplianceModule
 * @notice Interface for wallet/identity freeze compliance module instances.
 */
interface IWalletFreezeComplianceModule is IComplianceModule {

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Freeze modes for wallets/identities.
    enum FreezeMode {
        NONE,
        FULL,
        SEND_ONLY,
        RECEIVE_ONLY,
        ONLY_TO_TREASURY
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when wallet freeze mode changes
    event WalletFreezeModeSet(address indexed wallet, FreezeMode previousMode, FreezeMode newMode);

    /// @notice Emitted when identity freeze mode changes
    event IdentityFreezeModeSet(address indexed identity, FreezeMode previousMode, FreezeMode newMode);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the sender is restricted by freeze (wallet or identity mode).
    error FreezeModule_SenderRestricted(address wallet);

    /// @notice Thrown when the receiver is restricted by freeze (wallet or identity mode).
    error FreezeModule_ReceiverRestricted(address wallet);

    /// @notice Thrown when using the zero address where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when provided arrays do not have the same length
    error InvalidArrayLength();

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets freeze mode for one wallet.
    function setWalletMode(address wallet, FreezeMode mode) external;

    /// @notice Sets freeze mode for multiple wallets.
    function setWalletModes(address[] calldata wallets, FreezeMode[] calldata modes) external;

    /// @notice Sets freeze mode for one identity.
    function setIdentityMode(address identity, FreezeMode mode) external;

    /// @notice Sets freeze mode for multiple identities.
    function setIdentityModes(address[] calldata identities, FreezeMode[] calldata modes) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns identity registry used to resolve wallet bindings.
     */
    function identityRegistry() external view returns (IIdentityRegistry);

    /// @notice Returns wallet freeze mode.
    function walletMode(address wallet) external view returns (FreezeMode);

    /// @notice Returns identity freeze mode.
    function identityMode(address identity) external view returns (FreezeMode);

    /// @notice Returns treasury address used by ONLY_TO_TREASURY mode.
    function treasury() external view returns (address);
}
