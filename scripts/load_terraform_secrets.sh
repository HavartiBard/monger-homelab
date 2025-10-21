#!/bin/bash
# Load secrets from Ansible Vault into Terraform environment variables
# This is a workaround for WSL where 1Password desktop app isn't accessible

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VAULT_FILE="$PROJECT_DIR/inventory/raclette/group_vars/vault.yml"
VAULT_PASS_FILE="${HOME}/.vault_pass"

echo "🔐 Loading secrets from Ansible Vault for Terraform..."

# Check if vault file exists
if [ ! -f "$VAULT_FILE" ]; then
    echo "❌ Vault file not found: $VAULT_FILE"
    echo "Run: bash scripts/sync_secrets_from_1password_v2.sh"
    exit 1
fi

# Check if vault password exists
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo "❌ Vault password file not found: $VAULT_PASS_FILE"
    exit 1
fi

# Decrypt vault and extract values
echo "📥 Decrypting vault..."
VAULT_CONTENT=$(ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE")

# Extract specific values
PROXMOX_TOKEN=$(echo "$VAULT_CONTENT" | grep "^vault_proxmox_token_secret:" | cut -d'"' -f2)
VM_PASSWORD=$(echo "$VAULT_CONTENT" | grep "^vault_vm_default_password:" | cut -d'"' -f2)
SSH_KEY=$(echo "$VAULT_CONTENT" | grep "^vault_ssh_public_key:" | cut -d'"' -f2)

# Export as Terraform variables
export TF_VAR_pm_api_token_secret="$PROXMOX_TOKEN"
export TF_VAR_vm_password="$VM_PASSWORD"
export TF_VAR_ssh_key="$SSH_KEY"

echo "✅ Secrets loaded into environment variables:"
echo "  - TF_VAR_pm_api_token_secret (${#PROXMOX_TOKEN} chars)"
echo "  - TF_VAR_vm_password (${#VM_PASSWORD} chars)"
echo "  - TF_VAR_ssh_key (${#SSH_KEY} chars)"
echo ""
echo "🚀 Run Terraform commands in this shell session:"
echo "  cd terraform"
echo "  terraform plan"
echo "  terraform apply"
echo ""
echo "Or source this script to set variables in your current shell:"
echo "  source scripts/load_terraform_secrets.sh"
