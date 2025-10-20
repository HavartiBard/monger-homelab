#!/bin/bash
# Load secrets from 1Password and export as environment variables
# Requires: 1Password CLI (op) installed and authenticated

set -e

echo "Loading secrets from 1Password..."

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

# Load Technitium DNS API tokens
echo "Loading Technitium DNS tokens..."
export TECHNITIUM_DNS1_TOKEN=$(op read "op://homelab/technitium-dns1/api_token")
export TECHNITIUM_DNS2_TOKEN=$(op read "op://homelab/technitium-dns2/api_token")

# Load Proxmox credentials (if needed)
# export PROXMOX_TOKEN_ID=$(op read "op://homelab/proxmox/token_id")
# export PROXMOX_TOKEN_SECRET=$(op read "op://homelab/proxmox/token_secret")

echo "✅ Secrets loaded successfully!"
echo ""
echo "Environment variables set:"
echo "  - TECHNITIUM_DNS1_TOKEN"
echo "  - TECHNITIUM_DNS2_TOKEN"
echo ""
echo "Run your Ansible playbooks now:"
echo "  ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_api_backup.yml"
