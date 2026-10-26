// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {IComplianceBase} from "../interfaces/IComplianceBase.sol";
import {IComplianceModule} from "../interfaces/IComplianceModule.sol";

/**
 * @title ComplianceBase
 * @notice Core compliance coordinator for regulated Token3643-style emissions
 */
contract ComplianceBase is IComplianceBase, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to execute admin operations (manage token binding and modules)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role allowed to manage pause state
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role allowed to upgrade the proxy
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Treasury address used by certain compliance rules and token flows
    address public treasury;

    /// @notice Token contract allowed to call compliance hooks
    address public token;

    /// @notice Registered compliance modules in the order they were added
    address[] public modulesList;

    /// @notice Quick lookup to check if a module is currently registered
    mapping(address module => bool isRegistered) public moduleIsRegistered;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Restricts a function so it can only be called by the bound token contract
    modifier onlyToken() {
        if (msg.sender != token) {
            revert NotTokenCaller();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComplianceBase
    function initialize(address admin, address complianceAdmin, address treasury_)
        external
        initializer
    {
        if (admin == address(0) || complianceAdmin == address(0) || treasury_ == address(0)) {
            revert ZeroAddress();
        }

        __AccessControl_init();
        __Pausable_init();

        // Grant roles to the admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, complianceAdmin);
        _grantRole(UPGRADER_ROLE, admin);

        treasury = treasury_;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComplianceBase
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc IComplianceBase
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @inheritdoc IComplianceBase
    function setToken(address token_) external onlyRole(ADMIN_ROLE) {
        if (token_ == address(0)) {
            revert ZeroAddress();
        }
        if (token != address(0)) {
            revert TokenAlreadySet();
        }
        token = token_;
    }

    /// @inheritdoc IComplianceBase
    function addModule(address module) external onlyRole(ADMIN_ROLE) {
        // Check if the module is the zero address
        if (module == address(0)) {
            revert ZeroAddress();
        }

        // Check if the module is already registered
        if (moduleIsRegistered[module]) {
            revert ModuleAlreadyAdded();
        }

        // Check if the module implements the IComplianceModule interface
        if (!ERC165Checker.supportsInterface(module, type(IComplianceModule).interfaceId)) {
            revert InvalidModule();
        }

        // Add the module to the list of registered modules
        modulesList.push(module);
        moduleIsRegistered[module] = true;

        emit ModuleAdded(module);
    }

    /// @inheritdoc IComplianceBase
    function removeModule(address module) external onlyRole(ADMIN_ROLE) {
        // Check if the module is registered
        if (!moduleIsRegistered[module]) {
            revert ModuleNotFound();
        }

        // Remove the module from the list of registered modules
        uint256 length = modulesList.length;
        for (uint256 i = 0; i < length; i++) {
            if (modulesList[i] == module) {
                uint256 lastIndex = length - 1;
                if (i != lastIndex) {
                    modulesList[i] = modulesList[lastIndex];
                }
                modulesList.pop();
                moduleIsRegistered[module] = false;

                emit ModuleRemoved(module);
                return;
            }
        }

        // If the module is not found, revert
        revert ModuleNotFound();
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IComplianceBase
    function paused() public view override(PausableUpgradeable, IComplianceBase) returns (bool) {
        return super.paused();
    }

    /// @inheritdoc IComplianceBase
    /// @dev Reverts with CompliancePaused() when paused; modules may revert with ClaimModule_*, FreezeModule_*; if a module returns false, reverts ModuleRejected(module).
    function canTransfer(address from, address to, uint256 amount) external view returns (bool) {
        if (paused()) {
            revert IComplianceBase.CompliancePaused();
        }

        uint256 length = modulesList.length;
        for (uint256 i = 0; i < length; i++) {
            address module = modulesList[i];
            if (!IComplianceModule(module).canTransfer(from, to, amount)) {
                revert IComplianceBase.ModuleRejected(module);
            }
        }

        return true;
    }

    /// @inheritdoc IComplianceBase
    function transferred(address from, address to, uint256 amount) external onlyToken {
        // Check if the contract is paused
        if (paused()) {
            revert EnforcedPause();
        }

        // Call the transferred function for each module
        uint256 length = modulesList.length;
        for (uint256 i = 0; i < length; i++) {
            IComplianceModule(modulesList[i]).transferred(from, to, amount);
        }
    }

    /// @inheritdoc IComplianceBase
    function modules() external view returns (address[] memory) {
        return modulesList;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE) {
        (newImplementation);
    }
}

