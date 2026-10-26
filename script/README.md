# Scripts

Terminal menu for production-oriented operations:
- deploy `TokenFactory` proxy
- create emissions through `TokenFactory`
- upgrade proxy contracts (all 8 UUPS proxies in the system)
- run emission-level admin onboarding operations (create identity, bind wallet -> identity)
- run compliance operations (topics, issuers, claims, freeze, pause)

## What is global vs per-emission

- **Global (deploy once)**:
  - `TokenFactory` proxy
  - `TopicCatalog` global proxy (auto-deployed during `TokenFactory.initialize`)
- **Per emission (deployed by `TokenFactory.createEmission`)**:
  - `IdentityRegistry`
  - `ComplianceBase`
  - `IdentityFactory`
  - `ClaimTopicsRegistry`
  - `TrustedIssuersRegistry`
  - `ClaimsRegistry`
  - `ClaimComplianceModule`
  - `WalletFreezeComplianceModule`
  - `Token3643`

So, `IdentityFactory` is **not** a standalone deploy step in normal operations.

## Usage

From the repo root:

```bash
# install gum (required for interactive menus)
# macOS (Homebrew): brew install gum
# go: go install github.com/charmbracelet/gum@latest

chmod +x script/scriptMaster.sh   # once
./script/scriptMaster.sh
./script/scriptMaster.sh --help   # show usage and variables
```

The script loads `.env` and `script/networks.json`, then shows:

1. **Deploy** – TokenFactory and Create Emission via TokenFactory.
2. **Upgrade** – all proxy contracts:
   - TokenFactory
   - IdentityRegistry
   - ComplianceBase
   - IdentityFactory
   - ClaimTopicsRegistry
   - TrustedIssuersRegistry
   - ClaimsRegistry
   - TopicCatalog
3. **Identity admin operations** – create identity, bind wallet->identity, create+bind flow.
4. **Compliance operations** – TopicCatalog, required topics, issuers, claims, freeze, pause/unpause.
5. **Exit**

`scriptMaster.sh` requires `ETHERSCAN_API_KEY` and always runs with `--verify` after `--broadcast`.

After `Deploy TokenFactory`, `Create Emission`, and every `Upgrade`, the script also:
- updates `deployments/addresses/<network>.json` (e.g. `arbitrum.json`, `arbitrum_sepolia.json`)
- refreshes ABIs in `deployments/abis/<Contract>.json`

Networks are defined in `script/networks.json` with:
- `chainId`
- `rpcEnv` (name of the RPC URL env var, e.g. `ARBITRUM_SEPOLIA_RPC_URL`)
- `label` (human-friendly name)

The menu only offers networks whose `rpcEnv` environment variable is set in `.env`.

## Variables in `.env`

- `DEPLOYER_PRIVATE_KEY` – Required.
- `ARBITRUM_MAINNET_RPC_URL` – RPC URL for Arbitrum mainnet (optional).
- `ARBITRUM_SEPOLIA_RPC_URL` – RPC URL for Arbitrum Sepolia testnet (optional).
- `ETHERSCAN_API_KEY` – Required by `scriptMaster.sh` (verification is always enabled).

**For upgrades** (you can set multiple proxies; the menu will use the one you select). The signer must have **UPGRADER_ROLE** on the chosen proxy:

- `TOKEN_FACTORY_PROXY`
- `IDENTITY_REGISTRY_PROXY`
- `COMPLIANCE_BASE_PROXY`
- `IDENTITY_FACTORY_PROXY`
- `CLAIM_TOPICS_REGISTRY_PROXY`
- `TRUSTED_ISSUERS_REGISTRY_PROXY`
- `CLAIMS_REGISTRY_PROXY`
- `TOPIC_CATALOG_PROXY`

**For Create Emission via TokenFactory** (full V2 stack):

- `TOKEN_FACTORY_PROXY`
- `EMISSION_ID` (string, hashed on-chain script side with `keccak256(bytes(EMISSION_ID))`)
- `EMISSION_NAME`, `EMISSION_SYMBOL`, `EMISSION_MAX_SUPPLY`
- `EMISSION_TREASURY`, `EMISSION_ADMIN`, `EMISSION_COMPLIANCE_ADMIN`, `EMISSION_AGENT`

**For Admin operations (emission-level):**

- Shared: `TOKEN_FACTORY_PROXY`, `EMISSION_ID`
- Create identity:
  - `IDENTITY_USER_ID_HASH` (bytes32 hex, e.g. `0x...`)
  - `IDENTITY_ADMIN`
- Bind wallet to identity:
  - `BIND_WALLET`
  - `BIND_IDENTITY`

**For Compliance operations:**

- Shared: `TOKEN_FACTORY_PROXY`, `EMISSION_ID`
- TopicCatalog:
  - `TOPIC_ID`, `TOPIC_CODE`, `TOPIC_DESCRIPTION`, `TOPIC_ACTIVE`
- Trusted issuers:
  - `ISSUER`, `ISSUER_TRUSTED`
- Claims:
  - `CLAIM_IDENTITY`, `CLAIM_TOPIC`, `CLAIM_DATA_HASH`, `CLAIM_VALID_TO`
- Freeze:
  - `FREEZE_WALLET`, `FREEZE_IDENTITY`, `FREEZE_MODE`
  - `FREEZE_MODE`: `0 NONE`, `1 FULL`, `2 SEND_ONLY`, `3 RECEIVE_ONLY`, `4 ONLY_TO_TREASURY`

## Structure

- `scriptMaster.sh` – Menu that invokes `forge script` (with `--verify` when ETHERSCAN_API_KEY is set) for recommended operations.
- `deploy/DeployTokenFactory.s.sol` – Deploys TokenFactory proxy (and global TopicCatalog in initialize).
- `deploy/CreateEmissionFromFactory.s.sol` – Creates a fully wired emission through `TokenFactory.createEmission(...)`.
- `upgrade/Upgrade<Contract>.s.sol` – One script per proxy contract (TokenFactory, IdentityRegistry, ComplianceBase, IdentityFactory, ClaimTopicsRegistry, TrustedIssuersRegistry, ClaimsRegistry, TopicCatalog). Token3643 has no proxy.
- `admin/CreateIdentityFromEmission.s.sol` – Creates identity via emission IdentityFactory.
- `admin/BindWalletIdentity.s.sol` – Binds wallet to identity via emission IdentityRegistry.
- `admin/CreateAndBindIdentity.s.sol` – Convenience onboarding script (create + bind in one run).
- `admin/WireEmissionCompliance.s.sol` – One-off: sets ComplianceBase token and adds claim + freeze modules (fixes transfers reverting with `NotTokenCaller` on existing emissions).
- `compliance/SetGlobalTopic.s.sol` – Adds topic to global TopicCatalog.
- `compliance/SetGlobalTopicActive.s.sol` – Activates/deactivates global topic.
- `compliance/AddEmissionRequiredTopic.s.sol` – Adds required topic to emission ClaimTopicsRegistry.
- `compliance/RemoveEmissionRequiredTopic.s.sol` – Removes required topic from emission ClaimTopicsRegistry.
- `compliance/SetEmissionTrustedIssuer.s.sol` – Sets trusted issuer in emission TrustedIssuersRegistry.
- `compliance/SetEmissionClaim.s.sol` – Sets claim in emission ClaimsRegistry.
- `compliance/RevokeEmissionClaim.s.sol` – Revokes claim in emission ClaimsRegistry.
- `compliance/SetEmissionWalletFreezeMode.s.sol` – Sets wallet freeze mode in emission freeze module.
- `compliance/SetEmissionIdentityFreezeMode.s.sol` – Sets identity freeze mode in emission freeze module.
- `compliance/PauseEmissionCompliance.s.sol` – Pauses emission ComplianceBase.
- `compliance/UnpauseEmissionCompliance.s.sol` – Unpauses emission ComplianceBase.
- `tools/export-deployments.js` – Node script (invoked by scriptMaster.sh) that writes `deployments/addresses/<network>.json` and exports ABIs from `out/` into `deployments/abis/<Contract>.json`.
- `deployments/addresses/<network>.json` – Address registry for that network (`global`, `emissions`, `upgrades`). Example: `arbitrum.json`, `arbitrum_sepolia.json`.
- `deployments/abis/<Contract>.json` – One ABI per contract (from Foundry `out/`).
