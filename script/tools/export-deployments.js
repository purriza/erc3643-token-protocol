#!/usr/bin/env node
/*
  Persist deployed addresses into deployments/addresses/<networkKey>.json (e.g. arbitrum.json, arbitrum_sepolia.json).
  Export contract ABIs from Foundry into deployments/abis/<Contract>.json.
  Invoked by scriptMaster.sh after deploy / create emission / upgrade.
  Reads action and addresses from env (DEPLOYMENTS_ACTION, NETWORK_KEY, *_RESULT, etc.).
*/

const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "../..");

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function readJson(filePath) {
  const content = fs.readFileSync(filePath, "utf8");
  return JSON.parse(content);
}

function writeJson(filePath, data) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n", "utf8");
}

function env(key, def = "") {
  return process.env[key] ?? def;
}

function persistAddresses() {
  const networkKey = env("NETWORK_KEY");
  const filePath = path.join(repoRoot, "deployments", "addresses", `${networkKey}.json`);
  const action = env("DEPLOYMENTS_ACTION");
  const now = new Date().toISOString();

  let net = {};
  if (fs.existsSync(filePath)) {
    net = readJson(filePath);
  }
  net.global = net.global || {};
  net.emissions = net.emissions || {};
  net.upgrades = net.upgrades || [];
  net.proxyImplementations = net.proxyImplementations || {};
  net.updatedAt = now;

  if (action === "token_factory_deploy") {
    const tf = (net.global.tokenFactory = net.global.tokenFactory || {});
    tf.proxy = env("TOKEN_FACTORY_PROXY_RESULT");
    tf.implementation = env("TOKEN_FACTORY_IMPL_RESULT");
    tf.updatedAt = now;

    const tc = (net.global.topicCatalog = net.global.topicCatalog || {});
    tc.proxy = env("TOPIC_CATALOG_PROXY_RESULT");
    tc.implementation = env("TOPIC_CATALOG_IMPL_RESULT") || tc.implementation;
    tc.updatedAt = now;
  } else if (action === "topic_catalog_deploy") {
    const tc = (net.global.topicCatalog = net.global.topicCatalog || {});
    tc.proxy = env("TOPIC_CATALOG_PROXY_RESULT");
    tc.implementation = env("TOPIC_CATALOG_IMPL_RESULT");
    tc.updatedAt = now;
  } else if (action === "trusted_issuers_registry_deploy") {
    const tir = (net.global.trustedIssuersRegistry = net.global.trustedIssuersRegistry || {});
    tir.proxy = env("TRUSTED_ISSUERS_REGISTRY_PROXY_RESULT");
    tir.implementation = env("TRUSTED_ISSUERS_REGISTRY_IMPL_RESULT");
    tir.updatedAt = now;
  } else if (action === "claims_registry_deploy") {
    const cr = (net.global.claimsRegistry = net.global.claimsRegistry || {});
    cr.proxy = env("CLAIMS_REGISTRY_PROXY_RESULT");
    cr.implementation = env("CLAIMS_REGISTRY_IMPL_RESULT");
    cr.updatedAt = now;
  } else if (action === "identity_factory_deploy") {
    const idf = (net.global.identityFactory = net.global.identityFactory || {});
    idf.proxy = env("IDENTITY_FACTORY_PROXY_RESULT");
    idf.implementation = env("IDENTITY_FACTORY_IMPL_RESULT");
    idf.updatedAt = now;
  } else if (action === "emission_deployer_manager_deploy") {
    const pdm = (net.global.emissionDeployerManager = net.global.emissionDeployerManager || {});
    pdm.address = env("EMISSION_DEPLOYER_MANAGER_RESULT");
    pdm.updatedAt = now;
  } else if (action === "create_emission") {
    const emissionId = env("EMISSION_ID");
    const emission = (net.emissions[emissionId] = net.emissions[emissionId] || {});
    emission.emissionIdHash = env("EMISSION_ID_HASH_RESULT");
    emission.updatedAt = now;
    emission.contracts = {
      token: env("EMISSION_TOKEN_RESULT"),
      identityRegistry: env("EMISSION_IDENTITY_REGISTRY_RESULT"),
      complianceBase: env("EMISSION_COMPLIANCE_BASE_RESULT"),
      claimTopicsRegistry: env("EMISSION_CLAIM_TOPICS_REGISTRY_RESULT"),
      claimComplianceModule: env("EMISSION_CLAIM_COMPLIANCE_MODULE_RESULT"),
      walletFreezeComplianceModule: env("EMISSION_WALLET_FREEZE_MODULE_RESULT"),
      treasury: env("EMISSION_TREASURY_RESULT"),
    };
  } else if (action === "upgrade") {
    const contract = env("UPGRADE_CONTRACT_NAME");
    const proxy = env("UPGRADE_PROXY_ADDRESS");
    const newImpl = env("UPGRADE_NEW_IMPL_ADDRESS");
    if (!proxy || !newImpl) {
      throw new Error("Missing proxy or new implementation for upgrade persistence");
    }
    net.upgrades.push({
      contract,
      proxy,
      newImplementation: newImpl,
      updatedAt: now,
    });
    net.proxyImplementations[proxy] = {
      contract,
      implementation: newImpl,
      updatedAt: now,
    };
    if (contract === "TokenFactory") {
      const tf = (net.global.tokenFactory = net.global.tokenFactory || {});
      tf.proxy = proxy;
      tf.implementation = newImpl;
      tf.updatedAt = now;
    } else if (contract === "TrustedIssuersRegistry") {
      const tir = (net.global.trustedIssuersRegistry = net.global.trustedIssuersRegistry || {});
      tir.proxy = proxy;
      tir.implementation = newImpl;
      tir.updatedAt = now;
    } else if (contract === "ClaimsRegistry") {
      const cr = (net.global.claimsRegistry = net.global.claimsRegistry || {});
      cr.proxy = proxy;
      cr.implementation = newImpl;
      cr.updatedAt = now;
    } else if (contract === "IdentityFactory") {
      const idf = (net.global.identityFactory = net.global.identityFactory || {});
      idf.proxy = proxy;
      idf.implementation = newImpl;
      idf.updatedAt = now;
    } else if (contract === "TopicCatalog") {
      const tc = (net.global.topicCatalog = net.global.topicCatalog || {});
      tc.proxy = proxy;
      tc.implementation = newImpl;
      tc.updatedAt = now;
    }
  }

  const tmpPath = filePath + ".tmp";
  writeJson(tmpPath, net);
  fs.renameSync(tmpPath, filePath);
}

/** Contract names; ABIs are read from out/<Name>.sol/<Name>.json */
const ABI_CONTRACT_NAMES = [
  "TokenFactory", "Token3643", "IdentityRegistry", "IdentityFactory", "Identity",
  "ComplianceBase", "ClaimComplianceModule", "WalletFreezeComplianceModule",
  "TopicCatalog", "ClaimTopicsRegistry", "TrustedIssuersRegistry", "ClaimsRegistry",
];

function exportAbis() {
  const abiDir = path.join(repoRoot, "deployments", "abis");
  ensureDir(abiDir);
  const outDir = path.join(repoRoot, "out");

  const exported = [];
  for (const name of ABI_CONTRACT_NAMES) {
    const artifactPath = path.join(outDir, `${name}.sol`, `${name}.json`);
    if (!fs.existsSync(artifactPath)) {
      continue;
    }
    try {
      const artifact = readJson(artifactPath);
      const abi = artifact.abi || [];
      const outPath = path.join(abiDir, `${name}.json`);
      writeJson(outPath, abi);
      exported.push(name);
    } catch (err) {
      console.error(`[export-deployments] Failed to export ABI for ${name}:`, err.message);
    }
  }
  return exported;
}

function main() {
  const action = env("DEPLOYMENTS_ACTION");
  if (!action) {
    console.error("[export-deployments] DEPLOYMENTS_ACTION not set");
    process.exit(1);
  }
  if (action !== "abis_only" && !env("NETWORK_KEY")) {
    console.error("[export-deployments] NETWORK_KEY not set");
    process.exit(1);
  }

  if (action !== "abis_only") {
    persistAddresses();
  }
  const abis = exportAbis();
  console.log(`[export-deployments] ok: action=${action} abis=${abis.length}`);
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error("[export-deployments] Failed:", err.message);
    process.exit(1);
  }
}
