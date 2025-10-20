# Secrets Management

## Overview

**1Password is the source of truth** → synced to **Ansible Vault** for all automation.

```
┌─────────────┐
│  1Password  │  ◀── Source of Truth
│  (homelab)  │      (Update secrets here)
└──────┬──────┘
       │
       │ sync (scripts/sync_secrets_from_1password.sh)
       ▼
┌─────────────┐
│Ansible Vault│  ◀── Used by ALL playbooks
│ (vault.yml) │      (Desktop + Automation)
└─────────────┘
```

## Quick Start

### 1. Install 1Password CLI

```bash
# Windows (WSL)
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli
```

### 2. Store Secrets in 1Password

Create vault `homelab` with these items:

- **technitium-dns1** → field: `api_token` → `op://homelab/technitium-dns1/api_token`
- **technitium-dns2** → field: `api_token` → `op://homelab/technitium-dns2/api_token`

### 3. Sync to Ansible Vault

```bash
cd /mnt/d/cluster/monger-homelab

# Sign in
eval $(op signin)

# Sync secrets
bash scripts/sync_secrets_from_1password.sh
```

This creates:
- `inventory/raclette/group_vars/vault.yml` (encrypted)
- `~/.vault_pass` (vault password - **back this up in 1Password!**)

### 4. Deploy to Automation Container

```bash
# Copy vault files
scp inventory/raclette/group_vars/vault.yml james@192.168.20.50:/tmp/
scp ~/.vault_pass james@192.168.20.50:/tmp/

# SSH and move files
ssh james@192.168.20.50
sudo su - automation
mv /tmp/vault.yml /opt/automation/monger-homelab/inventory/raclette/group_vars/
mv /tmp/.vault_pass ~/.vault_pass
chmod 600 ~/.vault_pass
```

## Daily Usage

### Desktop (Manual Playbooks)

```bash
cd /mnt/d/cluster/monger-homelab

# Run any playbook with vault
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_api_backup.yml \
  --vault-password-file ~/.vault_pass
```

### Automation Container (Cron Jobs)

Cron jobs automatically use `--vault-password-file ~/.vault_pass` (configured in `bootstrap_automation_lxc.yml`).

## When Secrets Change

### Update Workflow

1. **Update in 1Password** (source of truth)
2. **Sync to vault**:
   ```bash
   eval $(op signin)
   bash scripts/sync_secrets_from_1password.sh
   ```
3. **Deploy to automation**:
   ```bash
   scp inventory/raclette/group_vars/vault.yml james@192.168.20.50:/tmp/
   ssh james@192.168.20.50 "sudo mv /tmp/vault.yml /opt/automation/monger-homelab/inventory/raclette/group_vars/"
   ```

## Security Notes

✅ **Never commit secrets to git** - `.gitignore` protects `vault.yml`  
✅ **Vault password in 1Password** - Store `~/.vault_pass` content in 1Password  
✅ **Encrypted at rest** - `vault.yml` is AES256 encrypted  
✅ **Single source of truth** - 1Password is authoritative  

## Troubleshooting

### "Decryption failed"
- Vault password is wrong
- Check `~/.vault_pass` matches on both desktop and automation container

### "op: not signed in"
```bash
eval $(op signin)
```

### View encrypted vault
```bash
ansible-vault view inventory/raclette/group_vars/vault.yml --vault-password-file ~/.vault_pass
```

### Edit encrypted vault (not recommended - use 1Password instead)
```bash
ansible-vault edit inventory/raclette/group_vars/vault.yml --vault-password-file ~/.vault_pass
```

## Files

- `inventory/raclette/group_vars/vault.yml` - Encrypted secrets (git-ignored)
- `~/.vault_pass` - Vault password (git-ignored, back up in 1Password!)
- `scripts/sync_secrets_from_1password.sh` - Sync script
- `scripts/load_secrets_from_1password.sh` - **DEPRECATED** (old approach)

---

**Remember**: Always update secrets in 1Password first, then sync!
