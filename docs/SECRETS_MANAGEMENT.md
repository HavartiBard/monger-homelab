# Secrets Management

## Overview

This project uses **1Password as the source of truth**, synced to **Ansible Vault** for all automation.

**Never commit secrets to git!**

## Architecture

```
┌─────────────┐
│  1Password  │  ◀── Source of Truth
│  (homelab)  │      (Manual updates)
└──────┬──────┘
       │
       │ sync (scripts/sync_secrets_from_1password.sh)
       ▼
┌─────────────┐
│Ansible Vault│  ◀── Used by all playbooks
│ (vault.yml) │      (Desktop + Automation)
└─────────────┘
```

**Workflow:**
1. Update secrets in 1Password
2. Run sync script to update Ansible Vault
3. All playbooks use the encrypted vault

## Initial Setup

### 1. Install 1Password CLI

```bash
# Windows (WSL)
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli

# Verify
op --version
```

### 2. Store Secrets in 1Password

Create a vault called `homelab` with these items:

**Technitium DNS:**
- **technitium-dns1** → field: `password` (API token) → `op://homelab/technitium-dns1/password`
- **technitium-dns2** → field: `password` (API token) → `op://homelab/technitium-dns2/password`

**Proxmox:**
- **proxmox** → field: `password` (API token secret) → `op://homelab/proxmox/password`

**Note:** Use the `password` field type so Terraform's 1Password provider can read it

### 3. Sync to Ansible Vault

```bash
cd /mnt/d/cluster/monger-homelab

# Sign in to 1Password
eval $(op signin)

# Sync secrets to Ansible Vault
bash scripts/sync_secrets_from_1password.sh
```

This creates:
- `inventory/raclette/group_vars/vault.yml` (encrypted)
- `~/.vault_pass` (vault password - back this up in 1Password!)

## Terraform Integration

Terraform uses the 1Password provider to read secrets directly:

```bash
cd /mnt/d/cluster/monger-homelab/terraform

# Sign in to 1Password
eval $(op signin)

# Initialize Terraform with 1Password provider
terraform init

# Plan/Apply - secrets loaded automatically from 1Password
terraform plan
terraform apply
```

See `terraform/1password.tf` for configuration.

## Files

**Ansible:**
- `inventory/raclette/group_vars/vault.yml` - Encrypted secrets (git-ignored)
- `~/.vault_pass` - Vault password (git-ignored, back up in 1Password!)
- `scripts/sync_secrets_from_1password.sh` - Sync script

**Terraform:**
- `terraform/1password.tf` - 1Password provider configuration
- `terraform/vars.tf` - Variable definitions (no secrets)

---

**Remember**: Always update secrets in 1Password first, then sync (Ansible) or run terraform (auto-loads)!)
