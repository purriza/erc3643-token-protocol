# ERC-3643 Token Protocol (Identity + Claims)

Permissioned token stack based on `Token3643`, with modular compliance, on-chain
identity anchors and claim-based transfer checks. The design follows the
ERC-3643 / T-REX model for regulated and permissioned token issuance.

## Origin and license

This repository is a cleaned-up, rebranded copy of a permissioned tokenization
protocol I designed and implemented end to end as the sole author of the
contracts. It was deployed and verified on Arbitrum One and Arbitrum Sepolia
under a different name. Every Solidity file carries an MIT
`SPDX-License-Identifier` and is republished here under those terms; see
[LICENSE](LICENSE) for the copyright notice.

Deployment addresses, broadcast artifacts, execution traces, coverage reports
and internal tooling have been removed. What remains is the contract source,
the full test suite, the deployment and operations scripts, and the exported
ABIs. All addresses in `.env.example` and in the example recipient files are
placeholders and must be populated before running anything against a live
network.

## Architecture

Each emission deployed through `TokenFactory` includes:

- `Token3643` (non-upgradeable token)
- `IdentityRegistry` (UUPS proxy, wallet -> identity)
- `ComplianceBase` (UUPS proxy, module orchestrator + pause)
- `IdentityFactory` (UUPS proxy, creates per-user `Identity`)
- `ClaimTopicsRegistry` (UUPS proxy, required claim topics)
- `TrustedIssuersRegistry` (UUPS proxy, trusted claim issuers)
- `ClaimsRegistry` (UUPS proxy, identity/topic claims)
- `ClaimComplianceModule` (module plugged into `ComplianceBase`)
- `WalletFreezeComplianceModule` (module plugged into `ComplianceBase` for wallet/identity freeze)
- `TopicCatalog` (global UUPS proxy shared by all emissions)

Main compliance flow:

1. `ClaimTopicsRegistry` defines required topics.
2. Wallets are linked to identities in `IdentityRegistry`.
3. Claims are written in `ClaimsRegistry` by trusted issuers.
4. `ClaimComplianceModule` checks required topics on transfer.
5. `WalletFreezeComplianceModule` enforces wallet/identity freeze checks.
6. `ComplianceBase` aggregates modules and enforces pause/token-caller guards.

### Topic/Claim vs compliance module

Two ways to express a transfer rule:

- Model it as a **topic + claim** when the rule is a per-identity attribute attested
  in `ClaimsRegistry` (for example KYC, accredited investor or jurisdiction).
  The topic is registered in `TopicCatalog` and required per emission in
  `ClaimTopicsRegistry`. Adding one is a configuration change, with no new code to deploy.
- Model it as a **compliance module** when the rule depends on transfer context
  or on state the contracts own. `WalletFreezeComplianceModule` is the built-in
  case. `ComplianceBase` composes modules, so another rule is a new
  `IComplianceModule` plugged in without touching the token.

## Roles (high-level)

- `UPGRADER_ROLE`: upgrades UUPS contracts.
- `ADMIN_ROLE`: admin operations per contract.
- `PAUSER_ROLE`: pause/unpause in `ComplianceBase`.
- `COMPLIANCE_ADMIN_ROLE`: identity binding in `IdentityRegistry`.
- `AGENT_ROLE`: forced transfers in `Token3643`.

`DEFAULT_ADMIN_ROLE` is only for role administration and not used directly for business function guards.

## Repository layout

- `src/token`: token and factory contracts
- `src/identity`: identity anchor, factory and registry
- `src/claims`: claim-related registries
- `src/compliance`: compliance coordinator and modules
- `src/interfaces`: interfaces and shared errors/events
- `test/*`: suites grouped by domain
- `script/*`: deploy, upgrade, compliance and admin scripts
- `deployments/abis`: exported ABIs for off-chain consumers

## Development

Install dependencies:

```bash
git submodule update --init
npm install
```

Build:

```bash
forge build
```

Run tests:

```bash
forge test
```

Coverage (the suite was kept at 100% line coverage on `src/`):

```bash
npm run coverage
```

## Deployment

Recommended production flow:

1. Deploy `TokenFactory` proxy.
2. Call `TokenFactory.createEmission(...)` to deploy and wire the full stack.

Copy `.env.example` to `.env` and fill in RPC URLs, the deployer key and the
proxy addresses before running any script. `script/scriptMaster.sh` provides an
interactive menu over the deploy, upgrade, compliance and identity scripts; see
`script/README.md` for the environment variables each one needs.

Off-chain consumers read addresses from `deployments/addresses/<network>.json`.
That directory ships empty here because the original deployment addresses were
removed; it is regenerated from Foundry broadcast output via
`node script/tools/export-deployments.js`.

## Disclaimers

- **Audit**: these contracts were reviewed internally and deployed to production
  under their original name. This repository is published as a reference and
  portfolio artifact, not as deployment-ready code; any redeployment should be
  independently reviewed and audited.
- **Testing**: thoroughly test on a testnet before any production use.
- **Risk**: permissioned token systems carry both smart contract and regulatory
  risk; the compliance logic here is a mechanism, not legal advice.
