/**
 * Airdrop script for permissioned emissions using viem.
 *
 * Objective:
 * - Read a JSON file with recipients for a single emission.
 * - Send ERC20 transfers from the emission's treasury wallet to each recipient
 *   using the existing Token3643 contract (per-emission token).
 * - Respect all existing compliance / identity rules (we just call `transfer`).
 *
 * Requirements:
 * - Node.js (>= 18 recommended).
 * - `npm` with dependencies installed: `viem`, `dotenv` y `ts-node` (o similar).
 * - `deployments/addresses/<network>.json` must exist (e.g. `arbitrum_sepolia.json`)
 *   and contain the emission entry with its `contracts.token` address.
 * - `deployments/abis/Token3643.json` must exist (exported via `npm run abis:refresh`).
 *
 * Environment variables:
 * - `NETWORK_KEY`: key of the network file under deployments/addresses (e.g. "arbitrum_sepolia").
 * - `<RPC_ENV>`: RPC URL for that network, as defined in script/networks.json
 *   (e.g. `ARBITRUM_SEPOLIA_RPC_URL`).
 * - `TREASURY_PRIVATE_KEY`: private key of the treasury wallet (0x-prefixed hex).
 *
 * Usage examples (from repo root, using npm):
 *
 *  npx ts-node script/airdrop.ts \\
 *    --file recipients_emission1.json \\
 *    --emission-id emission1 \\
 *    --dry-run
 *
 *  npx ts-node script/airdrop.ts \\
 *    --file recipients_emission1.json \\
 *    --emission-id emission1
 *
 * The JSON file must contain an array of objects:
 * [
 *   { "wallet": "0xabc...", "amount": "1000000000000000000" },
 *   { "wallet": "0xdef...", "amount": "2500000000000000000" }
 * ]
 *
 * - `wallet`: recipient address (checksummed or not; will be validated).
 * - `amount`: string in wei (no decimals, already scaled).
 *
 * Notes:
 * - This script sends one transaction per recipient.
 * - In `--dry-run` mode, it only simulates transfers and prints what would be sent.
 */

import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import { createWalletClient, createPublicClient, http, formatEther, getAddress, parseAbi, Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";

type Recipient = {
  wallet: string;
  amount: string; // wei as string
};

type NetworkConfig = {
  chainId: number;
  rpcEnv: string;
  label: string;
};

type NetworksJson = Record<string, NetworkConfig>;

type DeploymentsAddresses = {
  global: {
    tokenFactory?: unknown;
    topicCatalog?: unknown;
    emissionDeployerManager?: unknown;
  };
  emissions: Record<
    string,
    {
      emissionIdHash: string;
      updatedAt: string;
      contracts: {
        token: string;
        identityRegistry: string;
        complianceBase: string;
        identityFactory: string;
        claimsRegistry: string;
        claimTopicsRegistry: string;
        trustedIssuersRegistry: string;
        claimComplianceModule: string;
        walletFreezeComplianceModule: string;
        treasury: string;
      };
    }
  >;
};

dotenv.config();

function parseArgs(argv: string[]) {
  // Very small argument parser for: --file, --emission-id, --dry-run
  const args: { file?: string; emissionId?: string; dryRun: boolean } = { dryRun: false };
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--file" && i + 1 < argv.length) {
      args.file = argv[++i];
    } else if (arg === "--emission-id" && i + 1 < argv.length) {
      args.emissionId = argv[++i];
    } else if (arg === "--dry-run") {
      args.dryRun = true;
    }
  }
  if (!args.file) {
    throw new Error("Missing --file <path-to-recipients.json>");
  }
  if (!args.emissionId) {
    throw new Error("Missing --emission-id <emissionKey> (e.g. emission1)");
  }
  return args;
}

function loadNetworks(): NetworksJson {
  const networksPath = path.resolve(__dirname, "networks.json");
  const content = fs.readFileSync(networksPath, "utf8");
  return JSON.parse(content) as NetworksJson;
}

function loadDeployments(networkKey: string): DeploymentsAddresses {
  const filePath = path.resolve(__dirname, "..", "deployments", "addresses", `${networkKey}.json`);
  const content = fs.readFileSync(filePath, "utf8");
  return JSON.parse(content) as DeploymentsAddresses;
}

function loadRecipients(filePath: string): Recipient[] {
  const content = fs.readFileSync(path.resolve(filePath), "utf8");
  const data = JSON.parse(content);
  if (!Array.isArray(data)) {
    throw new Error("Recipients file must be a JSON array");
  }
  return data as Recipient[];
}

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required env var: ${key}`);
  }
  return value;
}

async function main() {
  const { file, emissionId, dryRun } = parseArgs(process.argv);

  const networkKey = requireEnv("NETWORK_KEY"); // e.g. "arbitrum_sepolia"
  const networks = loadNetworks();
  const netCfg = networks[networkKey];
  if (!netCfg) {
    throw new Error(`Network key "${networkKey}" not found in script/networks.json`);
  }

  const rpcUrl = requireEnv(netCfg.rpcEnv);
  const pk = requireEnv("TREASURY_PRIVATE_KEY");

  const account = privateKeyToAccount(pk as Hex);

  const chain = {
    id: netCfg.chainId,
    name: netCfg.label,
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
  } as const;

  const publicClient = createPublicClient({
    chain: {
      id: chain.id,
      name: chain.name,
      nativeCurrency: chain.nativeCurrency,
      rpcUrls: chain.rpcUrls,
    },
    transport: http(rpcUrl),
  });

  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  });

  const deployments = loadDeployments(networkKey);
  const emission = deployments.emissions[emissionId!];
  if (!emission) {
    throw new Error(`Emission "${emissionId}" not found in deployments/addresses/${networkKey}.json`);
  }

  const tokenAddress = getAddress(emission.contracts.token);
  const treasuryAddress = getAddress(emission.contracts.treasury);

  if (treasuryAddress.toLowerCase() !== account.address.toLowerCase()) {
    console.warn(
      `WARNING: Signer (${account.address}) is not equal to recorded treasury (${treasuryAddress}).` +
        " Ensure you are using the correct private key.",
    );
  }

  const recipients = loadRecipients(file!);
  if (recipients.length === 0) {
    console.log("Recipients list is empty; nothing to do.");
    return;
  }

  // Basic validation of recipients and total amount.
  let totalAmount = 0n;
  const normalizedRecipients: { wallet: `0x${string}`; amount: bigint }[] = [];

  for (const [idx, r] of recipients.entries()) {
    try {
      const wallet = getAddress(r.wallet);
      const amount = BigInt(r.amount);
      if (amount <= 0n) {
        throw new Error("amount must be > 0");
      }
      normalizedRecipients.push({ wallet, amount });
      totalAmount += amount;
    } catch (err) {
      throw new Error(`Invalid recipient at index ${idx}: ${(err as Error).message}`);
    }
  }

  console.log(`Network       : ${networkKey} (${netCfg.label}, chainId=${netCfg.chainId})`);
  console.log(`Token         : ${tokenAddress}`);
  console.log(`Treasury      : ${treasuryAddress}`);
  console.log(`Signer        : ${account.address}`);
  console.log(`Recipients    : ${normalizedRecipients.length}`);
  console.log(`Total amount  : ${totalAmount.toString()} wei (~${formatEther(totalAmount)} tokens, assuming 18 decimals)`);
  console.log(`Mode          : ${dryRun ? "DRY-RUN (simulation only)" : "LIVE (sending transactions)"}`);

  // Token3643 is ERC20-compatible; we only need the transfer function for this script.
  const erc20TransferAbi = parseAbi([
    "function transfer(address to, uint256 amount) external returns (bool)",
    "function balanceOf(address account) external view returns (uint256)",
    "function decimals() external view returns (uint8)",
    "function name() external view returns (string)",
    "function symbol() external view returns (string)",
  ]);

  const [balanceBefore, name, symbol, decimals] = await Promise.all([
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20TransferAbi,
      functionName: "balanceOf",
      args: [treasuryAddress],
    }) as Promise<bigint>,
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20TransferAbi,
      functionName: "name",
      args: [],
    }) as Promise<string>,
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20TransferAbi,
      functionName: "symbol",
      args: [],
    }) as Promise<string>,
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20TransferAbi,
      functionName: "decimals",
      args: [],
    }) as Promise<number>,
  ]);

  console.log(
    `Token meta    : ${name} (${symbol}), decimals=${decimals}, treasury balance=${balanceBefore.toString()} (~${formatEther(balanceBefore)} tokens)`,
  );

  if (balanceBefore < totalAmount) {
    console.warn(
      `WARNING: Treasury balance (${balanceBefore.toString()} wei) is less than total airdrop amount (${totalAmount.toString()} wei).`,
    );
  }

  if (dryRun) {
    console.log("\nDry-run recipients preview:");
    for (const { wallet, amount } of normalizedRecipients) {
      console.log(`  - ${wallet} <= ${amount.toString()} wei (~${formatEther(amount)} tokens)`);
    }
    console.log("\nDry-run completed (no transactions sent).");
    return;
  }

  console.log("\nSending transfers...");

  let successCount = 0;
  let failureCount = 0;

  for (const { wallet, amount } of normalizedRecipients) {
    try {
      const hash = await walletClient.writeContract({
        address: tokenAddress,
        abi: erc20TransferAbi,
        functionName: "transfer",
        args: [wallet, amount],
      });

      console.log(`OK  tx=${hash} to=${wallet} amount=${amount.toString()} wei (~${formatEther(amount)} tokens)`);
      successCount++;
    } catch (err) {
      console.error(
        `FAIL to=${wallet} amount=${amount.toString()} wei (~${formatEther(amount)} tokens): ${(err as Error).message}`,
      );
      failureCount++;
    }
  }

  const balanceAfter = (await publicClient.readContract({
    address: tokenAddress,
    abi: erc20TransferAbi,
    functionName: "balanceOf",
    args: [treasuryAddress],
  })) as bigint;

  console.log("\nSummary:");
  console.log(`  Success : ${successCount}`);
  console.log(`  Failed  : ${failureCount}`);
  console.log(
    `  Balance : before=${balanceBefore.toString()} wei, after=${balanceAfter.toString()} wei (~${formatEther(balanceAfter)} tokens)`,
  );
}

main().catch((err) => {
  console.error("[airdrop] Failed:", err);
  process.exit(1);
});

