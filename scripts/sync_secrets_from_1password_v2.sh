#!/bin/bash
# Sync secrets from 1Password to Ansible Vault
# Uses config/secrets_mapping.yml to define what to sync

# Don't exit on error - we want to collect all failures
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/secrets_mapping.yml"
VAULT_FILE="$PROJECT_DIR/inventory/raclette/group_vars/vault.yml"
VAULT_PASS_FILE="${HOME}/.vault_pass"

echo "🔐 Syncing secrets from 1Password to Ansible Vault..."

# Check if op CLI is installed
if ! command -v op &> /dev/null; then
    echo "❌ 1Password CLI (op) not found!"
    echo "Install: https://developer.1password.com/docs/cli/get-started/"
    exit 1
fi

# Check if yq is installed (for parsing YAML)
if ! command -v yq &> /dev/null; then
    echo "❌ yq not found! Installing..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi

# Check if signed in
if ! op account list &> /dev/null; then
    echo "❌ Not signed in to 1Password"
    echo "Run: eval \$(op signin)"
    exit 1
fi

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
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

# Read 1Password vault name from config
OP_VAULT=$(yq eval '.onepassword_vault' "$CONFIG_FILE")
echo "📥 Fetching secrets from 1Password vault: $OP_VAULT"

# Check if old vault exists and compare
if [ -f "$VAULT_FILE" ]; then
    echo "📋 Checking for removed secrets..."
    
    # Decrypt old vault temporarily
    OLD_VAULT_CONTENT=$(timeout 5s ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" 2>/dev/null || echo "")
    
    if [ -n "$OLD_VAULT_CONTENT" ]; then
        # Extract vault variable names from old vault
        OLD_VARS=$(echo "$OLD_VAULT_CONTENT" | grep -E '^vault_' | cut -d: -f1 || echo "")
        
        # Get current config variables
        CURRENT_VARS=$(yq eval '.secrets[].vault_variable' "$CONFIG_FILE")
        
        # Check for removed variables
        REMOVED_VARS=()
        while IFS= read -r old_var; do
            if [ -n "$old_var" ] && ! echo "$CURRENT_VARS" | grep -q "^${old_var}$"; then
                REMOVED_VARS+=("$old_var")
            fi
        done <<< "$OLD_VARS"
        
        if [ ${#REMOVED_VARS[@]} -gt 0 ]; then
            echo "⚠️  Warning: ${#REMOVED_VARS[@]} variable(s) removed from config:"
            for var in "${REMOVED_VARS[@]}"; do
                echo "  - $var"
            done
            echo ""
        else
            echo "✅ No removed secrets"
        fi
    else
        echo "⚠️  Could not read old vault file"
    fi
else
    echo "📋 No existing vault file found"
fi
echo ""

# Start building vault file
VAULT_CONTENT="---
# Ansible Vault - Synced from 1Password
# Last synced: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# DO NOT EDIT MANUALLY - Use 1Password as source of truth
# Config: config/secrets_mapping.yml

"

# Read number of secrets
SECRET_COUNT=$(yq eval '.secrets | length' "$CONFIG_FILE")
SYNCED_COUNT=0
FAILED_SECRETS=()

# Loop through each secret in config
for i in $(seq 0 $((SECRET_COUNT - 1))); do
    ITEM=$(yq eval ".secrets[$i].onepassword_item" "$CONFIG_FILE")
    FIELD=$(yq eval ".secrets[$i].onepassword_field" "$CONFIG_FILE")
    VAR=$(yq eval ".secrets[$i].vault_variable" "$CONFIG_FILE")
    DESC=$(yq eval ".secrets[$i].description" "$CONFIG_FILE")
    
    echo "  Fetching: $ITEM"
    echo "    Field: $FIELD"
    echo "    Path: op://$OP_VAULT/$ITEM/$FIELD"
    
    # Fetch secret from 1Password with detailed error
    # Use double quotes to handle spaces in item/field names
    # Add timeout to prevent hanging
    SECRET=$(timeout 10s op read "op://${OP_VAULT}/${ITEM}/${FIELD}" 2>&1)
    EXIT_CODE=$?
    
    # Check for timeout
    if [ $EXIT_CODE -eq 124 ]; then
        echo "    ❌ Timeout (10s) - check if item exists"
        FAILED_SECRETS+=("$ITEM (field: $FIELD - timeout)")
        continue
    fi
    
    if [ $EXIT_CODE -ne 0 ]; then
        echo "    ❌ Failed to fetch"
        echo "    Error: $SECRET"
        FAILED_SECRETS+=("$ITEM (field: $FIELD)")
    elif [ -z "$SECRET" ]; then
        echo "    ❌ Empty value returned"
        FAILED_SECRETS+=("$ITEM (field: $FIELD - empty)")
    else
        echo "    ✅ Synced (${#SECRET} chars)"
        VAULT_CONTENT+="# $DESC
$VAR: \"$SECRET\"

"
        ((SYNCED_COUNT++))
    fi
done

# Check if any secrets failed
if [ ${#FAILED_SECRETS[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Warning: ${#FAILED_SECRETS[@]} secret(s) failed to sync:"
    for item in "${FAILED_SECRETS[@]}"; do
        echo "  - $item"
    done
    echo ""
    echo "Make sure these items exist in 1Password vault '$OP_VAULT'"
    
    if [ $SYNCED_COUNT -eq 0 ]; then
        echo "❌ No secrets synced. Aborting."
        exit 1
    fi
    
    read -p "Continue with partial sync? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Write vault file
echo "📝 Creating vault file..."
echo "$VAULT_CONTENT" > "$VAULT_FILE"

# Encrypt vault file
echo "🔒 Encrypting vault file..."
ansible-vault encrypt "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"

echo ""
echo "✅ Secrets synced successfully!"
echo ""
echo "📋 Summary:"
echo "  - Vault file: $VAULT_FILE (encrypted)"
echo "  - Password file: $VAULT_PASS_FILE"
echo "  - Secrets synced: $SYNCED_COUNT/$SECRET_COUNT"
echo ""
echo "🚀 Run playbooks with:"
echo "  ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_api_backup.yml --vault-password-file ~/.vault_pass"
