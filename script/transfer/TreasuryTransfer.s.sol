// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Token3643} from "../../src/token/Token3643.sol";

/**
 * @title TreasuryTransfer
 * @notice Simple helper script to send Token3643 tokens from an EOA (e.g. the treasury)
 *         to a recipient, for debugging / manual checks.
 *
 * @dev Required env:
 *      - TRANSFER_TOKEN: address of the Token3643 instance
 *      - TRANSFER_RECIPIENT: destination address
 *      - TRANSFER_AMOUNT: uint256 amount (in token units, including decimals)
 *
 *      Optional env:
 *      - TRANSFER_SENDER_PRIVATE_KEY: private key of the sender wallet in hex (0x...)
 *        If not set, falls back to DEPLOYER_PRIVATE_KEY.
 */
contract TreasuryTransfer is Script {
    function run() external {
        uint256 defaultKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 senderKey = vm.envOr("TRANSFER_SENDER_PRIVATE_KEY", defaultKey);

        address tokenAddr = vm.envAddress("TRANSFER_TOKEN");
        address recipient = vm.envAddress("TRANSFER_RECIPIENT");
        uint256 amount = vm.envUint("TRANSFER_AMOUNT");

        console.log("Token:", tokenAddr);
        console.log("From  :", vm.addr(senderKey));
        console.log("To    :", recipient);
        console.log("Amount:", amount);

        vm.startBroadcast(senderKey);
        bool ok = Token3643(tokenAddr).transfer(recipient, amount);
        vm.stopBroadcast();

        console.log("transfer returned:", ok);
    }
}

