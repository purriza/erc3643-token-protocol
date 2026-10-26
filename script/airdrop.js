#!/usr/bin/env node
/**
 * Airdrop script for permissioned emissions using viem (CommonJS version).
 *
 * Objetivo:
 * - Leer un JSON con destinatarios para un único proyecto.
 * - Enviar transfers ERC20 desde el treasury de ese proyecto usando Token3643.
 * - Respetar toda la lógica de compliance (simplemente llamamos a `transfer`).
 *
 * Uso (desde la raíz del repo):
 *
 *  NETWORK_KEY=arbitrum_sepolia TREASURY_PRIVATE_KEY=0x... \
 *  node script/airdrop.js \
 *    --file script/recipients_emission1_example.json \
 *    --emission-id emission1 \
 *    --dry-run
 *
 * Requisitos:
 * - Node.js >= 18
 * - npm install viem dotenv
 *
 * Formato del JSON de entrada:
 * [
 *   { "wallet": "0x...", "amount": "300000000000000000000" },
 *   { "wallet": "0x...", "amount": "500000000000000000000" }
 * ]
 */

const fs = require("fs");
const path = require("path");
const dotenv = require("dotenv");
const {
  createWalletClient,
  createPublicClient,
  http,
  formatEther,
  getAddress,
  parseAbi,
} = require("viem");
const { privateKeyToAccount } = require("viem/accounts");

dotenv.config();

function parseArgs(argv) {
  const args = { dryRun: false };
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
  if (!args.file) throw new Error("Missing --file <path-to-recipients.json>");
  if (!args.emissionId) throw new Error("Missing --emission-id <emissionKey> (e.g. emission1)");
  return args;
}

function loadNetworks() {
  const networksPath = path.resolve(__dirname, "networks.json");
  return JSON.parse(fs.readFileSync(networksPath, "utf8"));
}

function loadDeployments(networkKey) {
  const filePath = path.resolve(__dirname, "..", "deployments", "addresses", `${networkKey}.json`);
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function loadRecipients(filePath) {
  const content = fs.readFileSync(path.resolve(filePath), "utf8");
  const data = JSON.parse(content);
  if (!Array.isArray(data)) throw new Error("Recipients file must be a JSON array");
  return data;
}

function requireEnv(key) {
  const v = process.env[key];
  if (!v) throw new Error(`Missing required env var: ${key}`);
  return v;
}

function normalizePrivateKey(pkRaw) {
  // Trim whitespace and remove optional surrounding quotes.
  let pk = pkRaw.trim();
  if ((pk.startsWith('"') && pk.endsWith('"')) || (pk.startsWith("'") && pk.endsWith("'"))) {
    pk = pk.slice(1, -1);
  }
  // Ensure it starts with 0x.
  if (!pk.startsWith("0x")) {
    pk = "0x" + pk;
  }
  // Basic validation of hex format.
  const hexBody = pk.slice(2);
  if (!/^[0-9a-fA-F]{64}$/.test(hexBody)) {
    throw new Error(
      `TREASURY_PRIVATE_KEY must be 32-byte hex (64 hex chars). Got length=${hexBody.length}`,
    );
  }
  return pk;
}

async function main() {
  const { file, emissionId, dryRun } = parseArgs(process.argv);

  const networkKey = requireEnv("NETWORK_KEY");
  const networks = loadNetworks();
  const netCfg = networks[networkKey];
  if (!netCfg) throw new Error(`Network key "${networkKey}" not found in script/networks.json`);

  const rpcUrl = requireEnv(netCfg.rpcEnv);
  const pk = normalizePrivateKey(requireEnv("TREASURY_PRIVATE_KEY"));
  const account = privateKeyToAccount(pk);

  const chain = {
    id: netCfg.chainId,
    name: netCfg.label,
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
  };

  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  });

  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  });

  const deployments = loadDeployments(networkKey);
  const emission = deployments.emissions[emissionId];
  if (!emission) {
    throw new Error(
      `Emission "${emissionId}" not found in deployments/addresses/${networkKey}.json`,
    );
  }

  const tokenAddress = getAddress(emission.contracts.token);
  const treasuryAddress = getAddress(emission.contracts.treasury);

  if (treasuryAddress.toLowerCase() !== account.address.toLowerCase()) {
    console.warn(
      `WARNING: Signer (${account.address}) is not equal to recorded treasury (${treasuryAddress}).`,
    );
  }

  const recipients = loadRecipients(file);
  if (recipients.length === 0) {
    console.log("Recipients list is empty; nothing to do.");
    return;
  }

  let totalAmount = 0n;
  const normalizedRecipients = [];
  recipients.forEach((r, idx) => {
    try {
      const wallet = getAddress(r.wallet);
      const amount = BigInt(r.amount);
      if (amount <= 0n) throw new Error("amount must be > 0");
      normalizedRecipients.push({ wallet, amount });
      totalAmount += amount;
    } catch (err) {
      throw new Error(`Invalid recipient at index ${idx}: ${err.message}`);
    }
  });

  console.log(`Network       : ${networkKey} (${netCfg.label}, chainId=${netCfg.chainId})`);
  console.log(`Token         : ${tokenAddress}`);
  console.log(`Treasury      : ${treasuryAddress}`);
  console.log(`Signer        : ${account.address}`);
  console.log(`Recipients    : ${normalizedRecipients.length}`);
  console.log(
    `Total amount  : ${totalAmount.toString()} wei (~${formatEther(
      totalAmount,
    )} tokens, assuming 18 decimals)`,
  );
  console.log(`Mode          : ${dryRun ? "DRY-RUN (simulation only)" : "LIVE (sending transactions)"}`);

  const erc20Abi = parseAbi([
    "function transfer(address to, uint256 amount) external returns (bool)",
    "function balanceOf(address account) external view returns (uint256)",
    "function decimals() external view returns (uint8)",
    "function name() external view returns (string)",
    "function symbol() external view returns (string)",
  ]);

  const [balanceBefore, name, symbol, decimals] = await Promise.all([
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [treasuryAddress],
    }),
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "name",
      args: [],
    }),
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "symbol",
      args: [],
    }),
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "decimals",
      args: [],
    }),
  ]);

  console.log(
    `Token meta    : ${name} (${symbol}), decimals=${decimals}, treasury balance=${balanceBefore.toString()} (~${formatEther(
      balanceBefore,
    )} tokens)`,
  );

  if (balanceBefore < totalAmount) {
    console.warn(
      `WARNING: Treasury balance (${balanceBefore.toString()} wei) is less than total airdrop amount (${totalAmount.toString()} wei).`,
    );
  }

  if (dryRun) {
    console.log("\nDry-run recipients preview:");
    normalizedRecipients.forEach(({ wallet, amount }) => {
      console.log(
        `  - ${wallet} <= ${amount.toString()} wei (~${formatEther(amount)} tokens)`,
      );
    });
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
        abi: erc20Abi,
        functionName: "transfer",
        args: [wallet, amount],
      });
      console.log(
        `OK  tx=${hash} to=${wallet} amount=${amount.toString()} wei (~${formatEther(
          amount,
        )} tokens)`,
      );
      successCount++;
    } catch (err) {
      console.error(
        `FAIL to=${wallet} amount=${amount.toString()} wei (~${formatEther(
          amount,
        )} tokens): ${err.message}`,
      );
      failureCount++;
    }
  }

  const balanceAfter = await publicClient.readContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [treasuryAddress],
  });

  console.log("\nSummary:");
  console.log(`  Success : ${successCount}`);
  console.log(`  Failed  : ${failureCount}`);
  console.log(
    `  Balance : before=${balanceBefore.toString()} wei, after=${balanceAfter.toString()} wei (~${formatEther(
      balanceAfter,
    )} tokens)`,
  );
}

main().catch((err) => {
  console.error("[airdrop] Failed:", err);
  process.exit(1);
});

