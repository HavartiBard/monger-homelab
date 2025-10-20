#!/bin/bash
# Sync secrets from 1Password to Ansible Vault
# This creates/updates the vault.yml file with secrets from 1Password

set -e

VAULT_FILE="inventory/raclette/group_vars/vault.yml"
VAULT_PASS_FILE="${HOME}/.vault_pass"

echo "🔐 Syncing secrets from 1Password to Ansible Vault..."

# Check if op CLI is installed
if ! command -v op &> /dev/null; then
    echo "❌ 1Password CLI (op) not found!"
    echo "Install: https://developer.1password.com/docs/cli/get-started/"
    exit 1
fi

# Check if signed in
if ! op account list &> /dev/null; then
    echo "❌ Not signed in to 1Password"
    echo "Run: eval \$(op signin)"
    exit 1
fi

# Check if vault password exists
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo "⚠️  Vault password file not found at $VAULT_PASS_FILE"
    echo "Creating new vault password..."
    
    # Generate random password
    VAULT_PASS=$(openssl rand -base64 32)
    echo "$VAULT_PASS" > "$VAULT_PASS_FILE"
    chmod 600 "$VAULT_PASS_FILE"
    
    echo "✅ Created vault password at $VAULT_PASS_FILE"
    echo "⚠️  IMPORTANT: Back this up in 1Password!"
    echo "   Store in: op://homelab/ansible-vault/password"
fi

# Fetch secrets from 1Password
echo "📥 Fetching secrets from 1Password..."
DNS1_TOKEN=$(op read "op://homelab/technitium-dns1/password" 2>/dev/null || echo "")
DNS2_TOKEN=$(op read "op://homelab/technitium-dns2/password" 2>/dev/null || echo "")

if [ -z "$DNS1_TOKEN" ] || [ -z "$DNS2_TOKEN" ]; then
    echo "❌ Failed to fetch tokens from 1Password"
    echo "Make sure these items exist with 'password' field:"
    echo "  - op://homelab/technitium-dns1/password"
    echo "  - op://homelab/technitium-dns2/password"
    exit 1
fi

# Create vault file
echo "📝 Creating vault file..."
cat > "$VAULT_FILE" <<EOF
---
# Ansible Vault - Synced from 1Password
# Last synced: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# DO NOT EDIT MANUALLY - Use 1Password as source of truth

vault_technitium_dns1_token: "$DNS1_TOKEN"
vault_technitium_dns2_token: "$DNS2_TOKEN"
EOF

# Encrypt vault file
echo "🔒 Encrypting vault file..."
ansible-vault encrypt "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"

echo ""
echo "✅ Secrets synced successfully!"
echo ""
echo "📋 Summary:"
echo "  - Vault file: $VAULT_FILE (encrypted)"
echo "  - Password file: $VAULT_PASS_FILE"
echo "  - Secrets synced: 2"
echo ""
echo "🚀 Run playbooks with:"
echo "  ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_api_backup.yml --vault-password-file ~/.vault_pass"
