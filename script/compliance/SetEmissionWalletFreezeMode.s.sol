// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ITokenFactory} from "../../src/interfaces/ITokenFactory.sol";
import {IComplianceBase} from "../../src/interfaces/IComplianceBase.sol";
import {IWalletFreezeComplianceModule} from "../../src/interfaces/IWalletFreezeComplianceModule.sol";

/**
 * @notice Sets wallet freeze mode in emission WalletFreezeComplianceModule.
 * @dev Uses the freeze module currently registered in ComplianceBase (not the factory),
 *      so it works after replaceModule (remove old + add new).
 *      Required env: TOKEN_FACTORY_PROXY, EMISSION_ID, FREEZE_WALLET, FREEZE_MODE
 *      FREEZE_MODE: 0 NONE, 1 FULL, 2 SEND_ONLY, 3 RECEIVE_ONLY, 4 ONLY_TO_TREASURY
 */
contract SetEmissionWalletFreezeMode is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenFactoryProxy = vm.envAddress("TOKEN_FACTORY_PROXY");
        bytes32 emissionId = keccak256(bytes(vm.envString("EMISSION_ID")));
        address wallet = vm.envAddress("FREEZE_WALLET");
        uint8 modeRaw = uint8(vm.envUint("FREEZE_MODE"));
        if (modeRaw > 4) revert("Invalid freeze mode");

        (, , address complianceAddr, , , , , , , ) = ITokenFactory(tokenFactoryProxy).emissions(emissionId);
        if (complianceAddr == address(0)) revert("Emission not found");

        address freezeModuleAddr = _findFreezeModule(complianceAddr);
        if (freezeModuleAddr == address(0)) revert("No WalletFreezeComplianceModule in ComplianceBase");

        vm.startBroadcast(deployerKey);
        IWalletFreezeComplianceModule(freezeModuleAddr).setWalletMode(
            wallet, IWalletFreezeComplianceModule.FreezeMode(modeRaw)
        );
        vm.stopBroadcast();

        console.log("--- Wallet freeze set ---");
        console.log("Emission ID (raw):", vm.envString("EMISSION_ID"));
        console.log("WalletFreezeModule:", freezeModuleAddr);
        console.log("Wallet:", wallet);
        console.log("Mode:", modeRaw);
    }

    function _findFreezeModule(address compliance) internal view returns (address) {
        address[] memory modules = IComplianceBase(compliance).modules();
        bytes4 freezeInterfaceId = type(IWalletFreezeComplianceModule).interfaceId;
        for (uint256 i = 0; i < modules.length; i++) {
            if (IERC165(modules[i]).supportsInterface(freezeInterfaceId)) {
                return modules[i];
            }
        }
        return address(0);
    }
}
