// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IToken3643} from "../interfaces/IToken3643.sol";
import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {IComplianceBase} from "../interfaces/IComplianceBase.sol";

/**
 * @title Token3643
 * @notice ERC-20 style regulated token with identity and modular compliance checks
 * @dev Integrates IdentityRegistry and ComplianceBase
 */
contract Token3643 is IToken3643, ERC20, AccessControl {
    
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to execute admin operations (manage registry, compliance and treasury)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role allowed to manage compliance-related configuration
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");

    /// @notice Role allowed to perform forced transfers
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Identity registry used to fetch KYC / AML status for addresses
    IIdentityRegistry public registry;

    /// @notice Compliance engine used to validate whether transfers are allowed
    IComplianceBase public compliance;

    /// @notice Treasury address that receives newly minted tokens and certain special flows
    address public treasury;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys a new Token3643 instance
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param registry_ Address of the IdentityRegistry instance
     * @param compliance_ Address of the ComplianceBase instance
     * @param treasury_ Address of the treasury wallet
     * @param admin_ Address that will receive the DEFAULT_ADMIN_ROLE
     * @param complianceAdmin_ Address that will receive the COMPLIANCE_ADMIN_ROLE
     * @param agent_ Address that will receive the AGENT_ROLE
     * @param maxSupply_ Max supply minted to treasury in constructor
     */
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
    ) ERC20(name_, symbol_) {
        if (
            registry_ == address(0) || compliance_ == address(0) || treasury_ == address(0) || admin_ == address(0)
                || complianceAdmin_ == address(0) || agent_ == address(0)
        ) {
            revert ZeroAddress();
        }

        // Set the registry, compliance, treasury and initial supply
        registry = IIdentityRegistry(registry_);
        compliance = IComplianceBase(compliance_);
        treasury = treasury_;

        // Grant roles to the admin, compliance admin and agent
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(COMPLIANCE_ADMIN_ROLE, complianceAdmin_);
        _grantRole(AGENT_ROLE, agent_);

        // Mint full supply to treasury on deployment
        _mint(treasury_, maxSupply_);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN / EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IToken3643
    function setRegistry(address registry_) external onlyRole(ADMIN_ROLE) {
        if (registry_ == address(0)) {
            revert ZeroAddress();
        }
        registry = IIdentityRegistry(registry_);
    }

    /// @inheritdoc IToken3643
    function setCompliance(address compliance_) external onlyRole(ADMIN_ROLE) {
        if (compliance_ == address(0)) {
            revert ZeroAddress();
        }
        compliance = IComplianceBase(compliance_);
        if (!compliance.canTransfer(treasury, treasury, 0)) {
            revert ComplianceRejected();
        }
    }

    /// @inheritdoc IToken3643
    function setTreasury(address treasury_) external onlyRole(ADMIN_ROLE) {
        if (treasury_ == address(0)) {
            revert ZeroAddress();
        }
        if (!compliance.canTransfer(address(0), treasury_, 0)) {
            revert ComplianceRejected();
        }
        treasury = treasury_;
    }

    /// @inheritdoc IToken3643
    function forcedTransfer(address from, address to, uint256 amount) external onlyRole(AGENT_ROLE) {
        if (from == address(0) || to == address(0)) {
            revert ZeroAddress();
        }
        _transfer(from, to, amount);
    }

    /// @inheritdoc IToken3643
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Core enforcement hook called on every transfer (and initial mint in constructor)
     * @param from Address from which tokens will be transferred
     * @param to Address to which tokens will be transferred
     * @param amount Amount of tokens to transfer
     */
    function _enforceCompliance(address from, address to, uint256 amount) internal view {
        // Normal transfer
        if (from != address(0) && to != address(0)) {
            if (!compliance.canTransfer(from, to, amount)) {
                revert ComplianceRejected();
            }

            return;
        }

        // Mint
        if (from == address(0) && to != address(0)) {
            if (to != treasury) {
                revert MintToNonTreasury(to);
            }
            if (!compliance.canTransfer(address(0), to, amount)) {
                revert ComplianceRejected();
            }

            return;
        }

        // Burn
        if (from != address(0) && to == address(0)) {
            return;
        }

        revert ComplianceRejected();
    }

    /**
     * @inheritdoc ERC20
     * @dev Central hook used to enforce identity and compliance rules
     * @param from Address from which tokens will be transferred
     * @param to Address to which tokens will be transferred
     * @param value Amount of tokens to transfer
     */
    function _update(address from, address to, uint256 value) internal override {
        // Enforce compliance
        _enforceCompliance(from, to, value);
        
        // Call the super._update function
        super._update(from, to, value);

        // Skip constructor mint (from == address(0)); for regular transfers/burns, always notify compliance.
        if (from != address(0)) {
            compliance.transferred(from, to, value);
        }
    }
}

