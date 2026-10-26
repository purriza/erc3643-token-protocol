#!/bin/bash
#
# Menu to run production-oriented deploy/upgrade/admin flows.
# Invokes forge script with --rpc-url, --broadcast and mandatory --verify on deployments/upgrades.
#

set -e
cd "$(dirname "$0")/.."

# Colors and log helpers (shell-scripts.mdc)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status()  { echo -e "${BLUE}[*]${NC} $*"; }
print_success() { echo -e "${GREEN}[+]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
print_error()   { echo -e "${RED}[x]${NC} $*" >&2; }

show_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Menu-driven deploy/upgrade/admin for TokenFactory and emission operations.
Loads .env from repo root and guides actions by area/role.

Options:
  -h, --help    Show this help and exit.

Environment variables in .env:
  DEPLOYER_PRIVATE_KEY           Deployer private key.
  ETHERSCAN_API_KEY              Etherscan API key.

Networks:
  You choose the target network at runtime from those that have an RPC URL configured (networks.json)

Examples:
  $0
  $0 --help
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) show_help; exit 0 ;;
  esac
done

if [ ! -f .env ]; then
  print_error ".env not found. Create it from .env.example and set DEPLOYER_PRIVATE_KEY and RPC URL(s)."
  exit 1
fi

source .env

if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
  print_error "DEPLOYER_PRIVATE_KEY not set in .env"
  exit 1
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
  print_error "ETHERSCAN_API_KEY not set in .env (verification is mandatory)"
  exit 1
fi

if ! command -v gum >/dev/null 2>&1; then
  print_error "gum is required but not installed. See https://github.com/charmbracelet/gum"
  print_error "Install it (e.g. 'brew install gum' or 'go install github.com/charmbracelet/gum@latest') and re-run."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  print_error "jq is required but not installed. Please install jq and re-run."
  exit 1
fi

NETWORKS_JSON_PATH="script/networks.json"
if [ ! -f "$NETWORKS_JSON_PATH" ]; then
  print_error "Networks config not found at $NETWORKS_JSON_PATH"
  exit 1
fi

echo ""
print_status "Select network:"

declare -A NETWORK_CHAIN_ID
declare -A NETWORK_RPC_ENV
declare -A NETWORK_LABEL

NETWORK_OPTIONS=()
while IFS='|' read -r key chainId rpcEnv label; do
  [ -z "$key" ] && continue
  NETWORK_CHAIN_ID["$key"]="$chainId"
  NETWORK_RPC_ENV["$key"]="$rpcEnv"
  NETWORK_LABEL["$key"]="$label"
  rpc_val="${!rpcEnv}"
  if [ -n "$rpc_val" ]; then
    NETWORK_OPTIONS+=("$label")
  fi
done < <(jq -r 'to_entries[] | "\(.key)|\(.value.chainId)|\(.value.rpcEnv)|\(.value.label)"' "$NETWORKS_JSON_PATH")

if [ ${#NETWORK_OPTIONS[@]} -eq 0 ]; then
  print_error "No RPC URLs configured in .env for any network defined in $NETWORKS_JSON_PATH"
  exit 1
fi

NETWORK_LABEL_SELECTED=$(printf '%s\n' "${NETWORK_OPTIONS[@]}" | GUM_CHOOSE_PROMPT='' gum choose --cursor "➤ ")

# Resolve NETWORK_KEY from selected label
NETWORK_KEY=""
for key in "${!NETWORK_LABEL[@]}"; do
  if [ "${NETWORK_LABEL[$key]}" = "$NETWORK_LABEL_SELECTED" ]; then
    NETWORK_KEY="$key"
    break
  fi
done

if [ -z "$NETWORK_KEY" ]; then
  print_error "Invalid network selection"
  exit 1
fi

NETWORK_NAME="$NETWORK_KEY"
RPC_ENV="${NETWORK_RPC_ENV[$NETWORK_KEY]}"
RPC_URL="${!RPC_ENV}"
EXPECTED_CHAIN_ID="${NETWORK_CHAIN_ID[$NETWORK_KEY]}"

if [ -z "$RPC_URL" ]; then
  print_error "RPC URL environment variable '$RPC_ENV' is not set for selected network '$NETWORK_KEY'"
  exit 1
fi

CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
if [ -n "$EXPECTED_CHAIN_ID" ] && [ "$CHAIN_ID" != "$EXPECTED_CHAIN_ID" ]; then
  print_warning "RPC chainId ($CHAIN_ID) does not match expected ($EXPECTED_CHAIN_ID) for $NETWORK_NAME"
fi


VERIFY_ARGS="--verify --etherscan-api-key $ETHERSCAN_API_KEY"

require_env_vars() {
  echo ""
  print_status "This operation requires the following .env variables:"
  for v in "$@"; do
    echo "  - $v"
  done
  echo ""
  local choice
  choice=$(
    printf '%s\n' \
      "Continue" \
      "Cancel and exit" | \
    gum choose --cursor "➤ "
  )
  if [ "$choice" != "Continue" ]; then
    print_warning "Operation cancelled by user to adjust .env variables."
    return 1
  fi
  for v in "$@"; do
    if [ -z "${!v}" ]; then
      print_error "$v not set in .env"
      return 1
    fi
  done
  return 0
}

run_forge_script() {
  local output
  set +e
  output=$("$@" 2>&1)
  local status=$?
  set -e

  echo "$output"
  FORGE_LAST_OUTPUT="$output"

  if [ $status -ne 0 ]; then
    print_error "forge script failed"
    exit $status
  fi
}

extract_address_by_label() {
  local label="$1"
  printf '%s\n' "$FORGE_LAST_OUTPUT" | awk -v lbl="$label" '
    index($0, lbl) {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^0x[0-9a-fA-F]{40}$/) addr = $i
      }
    }
    END { if (addr != "") print addr }
  '
}

run_export_deployments() {
  local action="$1"
  export NETWORK_KEY DEPLOYMENTS_ACTION="$action"
  export TOKEN_FACTORY_PROXY_RESULT TOKEN_FACTORY_IMPL_RESULT TOPIC_CATALOG_PROXY_RESULT TOPIC_CATALOG_IMPL_RESULT \
    EMISSION_DEPLOYER_MANAGER_RESULT IDENTITY_FACTORY_PROXY_RESULT IDENTITY_FACTORY_IMPL_RESULT \
    TRUSTED_ISSUERS_REGISTRY_PROXY_RESULT TRUSTED_ISSUERS_REGISTRY_IMPL_RESULT \
    CLAIMS_REGISTRY_PROXY_RESULT CLAIMS_REGISTRY_IMPL_RESULT
  export EMISSION_ID EMISSION_ID_HASH_RESULT EMISSION_TOKEN_RESULT EMISSION_IDENTITY_REGISTRY_RESULT \
    EMISSION_COMPLIANCE_BASE_RESULT EMISSION_IDENTITY_FACTORY_RESULT EMISSION_CLAIMS_REGISTRY_RESULT \
    EMISSION_CLAIM_TOPICS_REGISTRY_RESULT EMISSION_TRUSTED_ISSUERS_REGISTRY_RESULT \
    EMISSION_CLAIM_COMPLIANCE_MODULE_RESULT EMISSION_WALLET_FREEZE_MODULE_RESULT EMISSION_TREASURY_RESULT
  export UPGRADE_CONTRACT_NAME UPGRADE_PROXY_ADDRESS UPGRADE_NEW_IMPL_ADDRESS
  node script/tools/export-deployments.js
}

mkdir -p deployments/addresses deployments/abis

while true; do

print_status "Network: $NETWORK_NAME"
print_status "Network key: $NETWORK_KEY (chainId=$CHAIN_ID)"
print_status "RPC: ${RPC_URL:0:50}..."
echo ""
MAIN_MENU_LABEL=$(
  printf '%s\n' \
    "1) Deploy contracts" \
    "2) Upgrade contracts" \
    "3) Compliance operations" \
    "4) Identity operations" \
    "5) Exit" | \
  gum choose --cursor "➤ "
)

case "$MAIN_MENU_LABEL" in
  "1) Deploy contracts"*) choice=1 ;;
  "2) Upgrade contracts"*) choice=2 ;;
  "3) Compliance operations"*) choice=3 ;;
  "4) Identity operations"*) choice=4 ;;
  "5) Exit"*) choice=5 ;;
  *) print_error "Invalid option"; exit 1 ;;
esac

case "$choice" in
  1)
    echo ""
    SUB_DEPLOY_LABEL=$(
      printf '%s\n' \
        "1) Deploy TopicCatalog" \
        "2) Deploy TrustedIssuersRegistry" \
        "3) Deploy IdentityFactory" \
        "4) Deploy ClaimsRegistry" \
        "5) Deploy EmissionDeployerManager" \
        "6) Deploy TokenFactory" \
        "7) Create Emission via TokenFactory" \
        "8) Back" | \
      gum choose --cursor "➤ "
    )
    case "$SUB_DEPLOY_LABEL" in
      "1) Deploy TopicCatalog"*) sub=1 ;;
      "2) Deploy TrustedIssuersRegistry"*) sub=2 ;;
      "3) Deploy IdentityFactory"*) sub=3 ;;
      "4) Deploy ClaimsRegistry"*) sub=4 ;;
      "5) Deploy EmissionDeployerManager"*) sub=5 ;;
      "6) Deploy TokenFactory"*) sub=6 ;;
      "7) Create Emission via TokenFactory"*) sub=7 ;;
      "8) Back"*) sub=8 ;;
      *) print_error "Invalid option"; exit 1 ;;
    esac
    case "$sub" in
      1)
        run_forge_script forge script script/deploy/DeployTopicCatalog.s.sol:DeployTopicCatalog \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        TOPIC_CATALOG_PROXY_RESULT=$(extract_address_by_label "TopicCatalog proxy (use this):")
        TOPIC_CATALOG_IMPL_RESULT=$(extract_address_by_label "TopicCatalog implementation:")
        if [ -z "$TOPIC_CATALOG_PROXY_RESULT" ] || [ -z "$TOPIC_CATALOG_IMPL_RESULT" ]; then
          print_error "Could not parse TopicCatalog deployment addresses from output"
          exit 1
        fi
        run_export_deployments topic_catalog_deploy
        print_success "Updated deployments/addresses/$NETWORK_KEY.json and deployments/abis/"
        ;;
      2)
        run_forge_script forge script script/deploy/DeployTrustedIssuersRegistry.s.sol:DeployTrustedIssuersRegistry \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        TRUSTED_ISSUERS_REGISTRY_PROXY_RESULT=$(extract_address_by_label "TrustedIssuersRegistry proxy (use this):")
        TRUSTED_ISSUERS_REGISTRY_IMPL_RESULT=$(extract_address_by_label "TrustedIssuersRegistry implementation:")
        if [ -z "$TRUSTED_ISSUERS_REGISTRY_PROXY_RESULT" ] || [ -z "$TRUSTED_ISSUERS_REGISTRY_IMPL_RESULT" ]; then
          print_error "Could not parse TrustedIssuersRegistry deployment addresses from output"
          exit 1
        fi
        run_export_deployments trusted_issuers_registry_deploy
        print_success "Updated deployments/addresses/$NETWORK_KEY.json and deployments/abis/"
        ;;
      3)
        run_forge_script forge script script/deploy/DeployIdentityFactory.s.sol:DeployIdentityFactory \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        IDENTITY_FACTORY_PROXY_RESULT=$(extract_address_by_label "IdentityFactory proxy (use this):")
        IDENTITY_FACTORY_IMPL_RESULT=$(extract_address_by_label "IdentityFactory implementation:")
        if [ -z "$IDENTITY_FACTORY_PROXY_RESULT" ] || [ -z "$IDENTITY_FACTORY_IMPL_RESULT" ]; then
          print_error "Could not parse IdentityFactory deployment addresses from output"
          exit 1
        fi
        run_export_deployments identity_factory_deploy
        print_success "Updated deployments/addresses/$NETWORK_KEY.json and deployments/abis/"
        ;;
      4)
        require_env_vars TOPIC_CATALOG_PROXY TRUSTED_ISSUERS_REGISTRY_PROXY || continue
        run_forge_script forge script script/deploy/DeployClaimsRegistry.s.sol:DeployClaimsRegistry \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        CLAIMS_REGISTRY_PROXY_RESULT=$(extract_address_by_label "ClaimsRegistry proxy (use this):")
        CLAIMS_REGISTRY_IMPL_RESULT=$(extract_address_by_label "ClaimsRegistry implementation:")
        if [ -z "$CLAIMS_REGISTRY_PROXY_RESULT" ] || [ -z "$CLAIMS_REGISTRY_IMPL_RESULT" ]; then
          print_error "Could not parse ClaimsRegistry deployment addresses from output"
          exit 1
        fi
        run_export_deployments claims_registry_deploy
        print_success "Updated deployments/addresses/$NETWORK_KEY.json and deployments/abis/"
        ;;
      5)
        require_env_vars TOPIC_CATALOG_PROXY CLAIMS_REGISTRY_PROXY TRUSTED_ISSUERS_REGISTRY_PROXY IDENTITY_FACTORY_PROXY || continue
        run_forge_script forge script script/deploy/DeployEmissionDeployerManager.s.sol:DeployEmissionDeployerManager \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        EMISSION_DEPLOYER_MANAGER_RESULT=$(extract_address_by_label "EmissionDeployerManager:")
        if [ -z "$EMISSION_DEPLOYER_MANAGER_RESULT" ]; then
          print_error "Could not parse EmissionDeployerManager address from output"
          exit 1
        fi
        run_export_deployments emission_deployer_manager_deploy
        print_success "Updated deployments/addresses/$NETWORK_KEY.json and deployments/abis/"
        ;;
      6)
        require_env_vars EMISSION_DEPLOYER_MANAGER TOPIC_CATALOG_PROXY || continue
        run_forge_script forge script script/deploy/DeployTokenFactory.s.sol:DeployTokenFactory \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        TOKEN_FACTORY_PROXY_RESULT=$(extract_address_by_label "TokenFactory proxy (use this):")
        TOKEN_FACTORY_IMPL_RESULT=$(extract_address_by_label "TokenFactory implementation:")
        if [ -z "$TOKEN_FACTORY_PROXY_RESULT" ] || [ -z "$TOKEN_FACTORY_IMPL_RESULT" ]; then
          print_error "Could not parse TokenFactory deployment addresses from output"
          exit 1
        fi
        TOPIC_CATALOG_PROXY_RESULT=$(cast call "$TOKEN_FACTORY_PROXY_RESULT" "topicCatalog()(address)" --rpc-url "$RPC_URL")
        if [ -z "$TOPIC_CATALOG_PROXY_RESULT" ]; then
          print_error "Could not resolve TopicCatalog proxy from TokenFactory"
          exit 1
        fi
        run_export_deployments token_factory_deploy
        print_success "Updated deployments/addresses/$NETWORK_KEY.json and deployments/abis/"
        ;;
      7)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID EMISSION_NAME EMISSION_SYMBOL EMISSION_MAX_SUPPLY EMISSION_TREASURY EMISSION_ADMIN EMISSION_COMPLIANCE_ADMIN EMISSION_AGENT || continue
        run_forge_script forge script script/deploy/CreateEmissionFromFactory.s.sol:CreateEmissionFromFactory \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        EMISSION_ID_HASH_RESULT=$(cast keccak "$EMISSION_ID")
        EMISSION_TOKEN_RESULT=$(extract_address_by_label "Token:")
        EMISSION_IDENTITY_REGISTRY_RESULT=$(extract_address_by_label "IdentityRegistry:")
        EMISSION_COMPLIANCE_BASE_RESULT=$(extract_address_by_label "ComplianceBase:")
        EMISSION_IDENTITY_FACTORY_RESULT=$(extract_address_by_label "IdentityFactory:")
        EMISSION_CLAIMS_REGISTRY_RESULT=$(extract_address_by_label "ClaimsRegistry:")
        EMISSION_CLAIM_TOPICS_REGISTRY_RESULT=$(extract_address_by_label "ClaimTopicsRegistry:")
        EMISSION_TRUSTED_ISSUERS_REGISTRY_RESULT=$(extract_address_by_label "TrustedIssuersRegistry:")
        EMISSION_CLAIM_COMPLIANCE_MODULE_RESULT=$(extract_address_by_label "ClaimComplianceModule:")
        EMISSION_WALLET_FREEZE_MODULE_RESULT=$(extract_address_by_label "WalletFreezeComplianceModule:")
        EMISSION_TREASURY_RESULT=$(extract_address_by_label "Treasury:")
        if [ -z "$EMISSION_TOKEN_RESULT" ] || [ -z "$EMISSION_IDENTITY_REGISTRY_RESULT" ] || [ -z "$EMISSION_COMPLIANCE_BASE_RESULT" ]; then
          print_error "Could not parse emission addresses from createEmission output"
          exit 1
        fi
        run_export_deployments create_emission
        print_success "Updated deployments/addresses/$NETWORK_KEY.json and deployments/abis/"
        ;;
      8) continue ;;
      *) print_error "Invalid option"; exit 1 ;;
    esac
    ;;
  2)
    echo ""
    echo "Upgrade (proxy address must be set in .env for the chosen contract):"
    SUB_UPGRADE_LABEL=$(
      printf '%s\n' \
        "1) TopicCatalog (TOPIC_CATALOG_PROXY) (global)" \
        "2) TrustedIssuersRegistry (TRUSTED_ISSUERS_REGISTRY_PROXY) (global)" \
        "3) IdentityFactory (IDENTITY_FACTORY_PROXY) (global)" \
        "4) ClaimsRegistry (CLAIMS_REGISTRY_PROXY) (global)" \
        "5) TokenFactory (TOKEN_FACTORY_PROXY) (global)" \
        "6) IdentityRegistry (IDENTITY_REGISTRY_PROXY) (emission)" \
        "7) ComplianceBase (COMPLIANCE_BASE_PROXY) (emission)" \
        "8) ClaimTopicsRegistry (CLAIM_TOPICS_REGISTRY_PROXY) (emission)" \
        "9) Back" | \
      gum choose --cursor "➤ "
    )
    case "$SUB_UPGRADE_LABEL" in
      "1) TopicCatalog (TOPIC_CATALOG_PROXY) (global)"*) sub=1 ;;
      "2) TrustedIssuersRegistry (TRUSTED_ISSUERS_REGISTRY_PROXY) (global)"*) sub=2 ;;
      "3) IdentityFactory (IDENTITY_FACTORY_PROXY) (global)"*) sub=3 ;;
      "4) ClaimsRegistry (CLAIMS_REGISTRY_PROXY) (global)"*) sub=4 ;;
      "5) TokenFactory (TOKEN_FACTORY_PROXY) (global)"*) sub=5 ;;
      "6) IdentityRegistry (IDENTITY_REGISTRY_PROXY) (emission)"*) sub=6 ;;
      "7) ComplianceBase (COMPLIANCE_BASE_PROXY) (emission)"*) sub=7 ;;
      "8) ClaimTopicsRegistry (CLAIM_TOPICS_REGISTRY_PROXY) (emission)"*) sub=8 ;;
      "9) Back"*) sub=9 ;;
      *) print_error "Invalid option"; exit 1 ;;
    esac
    case "$sub" in
      1)
        require_env_vars TOPIC_CATALOG_PROXY || continue
        run_forge_script forge script script/upgrade/UpgradeTopicCatalog.s.sol:UpgradeTopicCatalog \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        UPGRADE_CONTRACT_NAME="TopicCatalog"
        UPGRADE_PROXY_ADDRESS="$TOPIC_CATALOG_PROXY"
        UPGRADE_NEW_IMPL_ADDRESS=$(extract_address_by_label "New TopicCatalog implementation:")
        run_export_deployments upgrade
        ;;
      2)
        require_env_vars TRUSTED_ISSUERS_REGISTRY_PROXY || continue
        run_forge_script forge script script/upgrade/UpgradeTrustedIssuersRegistry.s.sol:UpgradeTrustedIssuersRegistry \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        UPGRADE_CONTRACT_NAME="TrustedIssuersRegistry"
        UPGRADE_PROXY_ADDRESS="$TRUSTED_ISSUERS_REGISTRY_PROXY"
        UPGRADE_NEW_IMPL_ADDRESS=$(extract_address_by_label "New TrustedIssuersRegistry implementation:")
        run_export_deployments upgrade
        ;;
      3)
        require_env_vars IDENTITY_FACTORY_PROXY || continue
        run_forge_script forge script script/upgrade/UpgradeIdentityFactory.s.sol:UpgradeIdentityFactory \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        UPGRADE_CONTRACT_NAME="IdentityFactory"
        UPGRADE_PROXY_ADDRESS="$IDENTITY_FACTORY_PROXY"
        UPGRADE_NEW_IMPL_ADDRESS=$(extract_address_by_label "New IdentityFactory implementation:")
        run_export_deployments upgrade
        ;;
      4)
        require_env_vars CLAIMS_REGISTRY_PROXY || continue
        run_forge_script forge script script/upgrade/UpgradeClaimsRegistry.s.sol:UpgradeClaimsRegistry \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        UPGRADE_CONTRACT_NAME="ClaimsRegistry"
        UPGRADE_PROXY_ADDRESS="$CLAIMS_REGISTRY_PROXY"
        UPGRADE_NEW_IMPL_ADDRESS=$(extract_address_by_label "New ClaimsRegistry implementation:")
        run_export_deployments upgrade
        ;;
      5)
        require_env_vars TOKEN_FACTORY_PROXY || continue
        run_forge_script forge script script/upgrade/UpgradeTokenFactory.s.sol:UpgradeTokenFactory \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        UPGRADE_CONTRACT_NAME="TokenFactory"
        UPGRADE_PROXY_ADDRESS="$TOKEN_FACTORY_PROXY"
        UPGRADE_NEW_IMPL_ADDRESS=$(extract_address_by_label "New TokenFactory implementation:")
        run_export_deployments upgrade
        ;;
      6)
        require_env_vars IDENTITY_REGISTRY_PROXY || continue
        run_forge_script forge script script/upgrade/UpgradeIdentityRegistry.s.sol:UpgradeIdentityRegistry \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        UPGRADE_CONTRACT_NAME="IdentityRegistry"
        UPGRADE_PROXY_ADDRESS="$IDENTITY_REGISTRY_PROXY"
        UPGRADE_NEW_IMPL_ADDRESS=$(extract_address_by_label "New IdentityRegistry implementation:")
        run_export_deployments upgrade
        ;;
      7)
        require_env_vars COMPLIANCE_BASE_PROXY || continue
        run_forge_script forge script script/upgrade/UpgradeComplianceBase.s.sol:UpgradeComplianceBase \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        UPGRADE_CONTRACT_NAME="ComplianceBase"
        UPGRADE_PROXY_ADDRESS="$COMPLIANCE_BASE_PROXY"
        UPGRADE_NEW_IMPL_ADDRESS=$(extract_address_by_label "New ComplianceBase implementation:")
        run_export_deployments upgrade
        ;;
      8)
        require_env_vars CLAIM_TOPICS_REGISTRY_PROXY || continue
        run_forge_script forge script script/upgrade/UpgradeClaimTopicsRegistry.s.sol:UpgradeClaimTopicsRegistry \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY" \
          $VERIFY_ARGS
        UPGRADE_CONTRACT_NAME="ClaimTopicsRegistry"
        UPGRADE_PROXY_ADDRESS="$CLAIM_TOPICS_REGISTRY_PROXY"
        UPGRADE_NEW_IMPL_ADDRESS=$(extract_address_by_label "New ClaimTopicsRegistry implementation:")
        run_export_deployments upgrade
        ;;
      9) continue ;;
      *) print_error "Invalid option"; exit 1 ;;
    esac
    ;;
  3)
    echo ""
    echo "Compliance operations:"
    SUB_COMPLIANCE_LABEL=$(
      printf '%s\n' \
        "1) TopicCatalog (global): Set topic" \
        "2) TopicCatalog (global): Set topic active/inactive" \
        "3) ClaimTopicsRegistry (emission): Add required topic" \
        "4) ClaimTopicsRegistry (emission): Remove required topic" \
        "5) TrustedIssuersRegistry (emission): Set trusted issuer" \
        "6) ClaimsRegistry (emission): Set claim" \
        "7) ClaimsRegistry (emission): Revoke claim" \
        "8) WalletFreezeComplianceModule (emission): Set wallet freeze mode" \
        "9) WalletFreezeComplianceModule (emission): Set identity freeze mode" \
        "10) ComplianceBase (emission): Pause compliance" \
        "11) ComplianceBase (emission): Unpause compliance" \
        "12) ComplianceBase (emission): Add module" \
        "13) ComplianceBase (emission): Remove module" \
        "14) Back" | \
      gum choose --cursor "➤ "
    )
    case "$SUB_COMPLIANCE_LABEL" in
      "1) TopicCatalog (global): Set topic"*) sub=1 ;;
      "2) TopicCatalog (global): Set topic active/inactive"*) sub=2 ;;
      "3) ClaimTopicsRegistry (emission): Add required topic"*) sub=3 ;;
      "4) ClaimTopicsRegistry (emission): Remove required topic"*) sub=4 ;;
      "5) TrustedIssuersRegistry (emission): Set trusted issuer"*) sub=5 ;;
      "6) ClaimsRegistry (emission): Set claim"*) sub=6 ;;
      "7) ClaimsRegistry (emission): Revoke claim"*) sub=7 ;;
      "8) WalletFreezeComplianceModule (emission): Set wallet freeze mode"*) sub=8 ;;
      "9) WalletFreezeComplianceModule (emission): Set identity freeze mode"*) sub=9 ;;
      "10) ComplianceBase (emission): Pause compliance"*) sub=10 ;;
      "11) ComplianceBase (emission): Unpause compliance"*) sub=11 ;;
      "12) ComplianceBase (emission): Add module"*) sub=12 ;;
      "13) ComplianceBase (emission): Remove module"*) sub=13 ;;
      "14) Back"*) sub=14 ;;
      *) print_error "Invalid option"; exit 1 ;;
    esac
    case "$sub" in
      1)
        require_env_vars TOKEN_FACTORY_PROXY TOPIC_ID TOPIC_CODE TOPIC_DESCRIPTION TOPIC_ACTIVE || continue
        forge script script/compliance/SetGlobalTopic.s.sol:SetGlobalTopic \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      2)
        require_env_vars TOKEN_FACTORY_PROXY TOPIC_ID TOPIC_ACTIVE || continue
        forge script script/compliance/SetGlobalTopicActive.s.sol:SetGlobalTopicActive \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      3)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID TOPIC_ID || continue
        forge script script/compliance/AddEmissionRequiredTopic.s.sol:AddEmissionRequiredTopic \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      4)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID TOPIC_ID || continue
        forge script script/compliance/RemoveEmissionRequiredTopic.s.sol:RemoveEmissionRequiredTopic \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      5)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID ISSUER ISSUER_TRUSTED || continue
        forge script script/compliance/SetEmissionTrustedIssuer.s.sol:SetEmissionTrustedIssuer \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      6)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID CLAIM_IDENTITY CLAIM_TOPIC CLAIM_DATA_HASH CLAIM_VALID_TO || continue
        forge script script/compliance/SetEmissionClaim.s.sol:SetEmissionClaim \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      7)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID CLAIM_IDENTITY CLAIM_TOPIC || continue
        forge script script/compliance/RevokeEmissionClaim.s.sol:RevokeEmissionClaim \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      8)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID FREEZE_WALLET FREEZE_MODE || continue
        forge script script/compliance/SetEmissionWalletFreezeMode.s.sol:SetEmissionWalletFreezeMode \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      9)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID FREEZE_IDENTITY FREEZE_MODE || continue
        forge script script/compliance/SetEmissionIdentityFreezeMode.s.sol:SetEmissionIdentityFreezeMode \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      10)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID || continue
        forge script script/compliance/PauseEmissionCompliance.s.sol:PauseEmissionCompliance \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      11)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID || continue
        forge script script/compliance/UnpauseEmissionCompliance.s.sol:UnpauseEmissionCompliance \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        ;;
      12)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID MODULE_TO_ADD || continue
        run_forge_script forge script script/compliance/AddComplianceModule.s.sol:AddComplianceModule \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        print_success "Module added to ComplianceBase."
        ;;
      13)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID MODULE_TO_REMOVE || continue
        run_forge_script forge script script/compliance/RemoveComplianceModule.s.sol:RemoveComplianceModule \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        print_success "Module removed from ComplianceBase."
        ;;
      14) continue ;;
      *) print_error "Invalid option"; exit 1 ;;
    esac
    ;;
  4)
    echo ""
    SUB_ADMIN_LABEL=$(
      printf '%s\n' \
        "1) Create Identity only (IdentityFactory)" \
        "2) Bind Wallet -> existing Identity (IdentityRegistry)" \
        "3) Create Identity + Bind Wallet (one-step onboarding)" \
        "4) Verify Identity contract (manual)" \
        "5) Back" | \
      gum choose --cursor "➤ "
    )
    case "$SUB_ADMIN_LABEL" in
      "1) Create Identity only (IdentityFactory)"*) sub=1 ;;
      "2) Bind Wallet -> existing Identity (IdentityRegistry)"*) sub=2 ;;
      "3) Create Identity + Bind Wallet (one-step onboarding)"*) sub=3 ;;
      "4) Verify Identity contract (manual)"*) sub=4 ;;
      "5) Back"*) sub=5 ;;
      *) print_error "Invalid option"; exit 1 ;;
    esac
    case "$sub" in
      1)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID IDENTITY_USER_ID_HASH IDENTITY_ADMIN || continue
        run_forge_script forge script script/admin/CreateIdentityFromEmission.s.sol:CreateIdentityFromEmission \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        print_success "Identity created. See addresses above (Identity: ...)."
        ;;
      2)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID BIND_WALLET BIND_IDENTITY || continue
        run_forge_script forge script script/admin/BindWalletIdentity.s.sol:BindWalletIdentity \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        print_success "Wallet bound to identity. See addresses above."
        ;;
      3)
        require_env_vars TOKEN_FACTORY_PROXY EMISSION_ID IDENTITY_USER_ID_HASH IDENTITY_ADMIN BIND_WALLET || continue
        run_forge_script forge script script/admin/CreateAndBindIdentity.s.sol:CreateAndBindIdentity \
          --rpc-url "$RPC_URL" \
          --broadcast \
          --private-key "$DEPLOYER_PRIVATE_KEY"
        print_success "Identity created and wallet bound. See addresses above (Identity: ..., Wallet: ...)."
        ;;
      4)
        require_env_vars IDENTITY_CONTRACT IDENTITY_USER_ID_HASH IDENTITY_ADMIN || continue
        encoded_args=$(cast abi-encode "constructor(address,bytes32)" "$IDENTITY_ADMIN" "$IDENTITY_USER_ID_HASH")
        forge verify-contract \
          --chain-id "$CHAIN_ID" \
          --etherscan-api-key "$ETHERSCAN_API_KEY" \
          "$IDENTITY_CONTRACT" \
          src/identity/Identity.sol:Identity \
          --constructor-args "$encoded_args"
        ;;
      5) continue ;;
      *) print_error "Invalid option"; exit 1 ;;
    esac
    ;;
  5)
    break
    ;;
  *)
    print_error "Invalid option"
    exit 1
    ;;
esac

done

echo ""
print_success "Done."
