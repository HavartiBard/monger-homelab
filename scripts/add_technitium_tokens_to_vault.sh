#!/bin/bash
# Script to add Technitium API tokens to Ansible vault
# This is a helper script - you still need to manually edit the vault

set -e

REPO_ROOT="/mnt/d/cluster/monger-homelab"
VAULT_FILE="$REPO_ROOT/inventory/raclette/group_vars/vault.yml"

echo "=========================================="
echo "Add Technitium Tokens to Ansible Vault"
echo "=========================================="
echo ""
echo "This script will help you add the Technitium API tokens to your vault."
echo ""
echo "Current tokens (from existing playbooks):"
echo "  technitium-dns1: f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8"
echo "  technitium-dns2: 819048ea9356f23157ab915dc4e8f9e2927ccaa206a207f61982c41da8842615"
echo ""
echo "You need to add these lines to your vault file:"
echo ""
echo "-------------------------------------------"
cat << 'EOF'
# Technitium DNS API Tokens
vault_technitium_tokens:
  technitium-dns1: "f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8"
  technitium-dns2: "819048ea9356f23157ab915dc4e8f9e2927ccaa206a207f61982c41da8842615"
EOF
echo "-------------------------------------------"
echo ""
echo "To edit the vault, run:"
echo "  cd $REPO_ROOT"
echo "  ansible-vault edit $VAULT_FILE"
echo ""
echo "After adding the tokens, test with:"
echo "  ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_api_backup.yml --ask-vault-pass --check"
echo ""
echo "Or if you have a vault password file:"
echo "  ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_api_backup.yml --vault-password-file ~/.vault_pass --check"
echo ""
