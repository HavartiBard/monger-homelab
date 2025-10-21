# Technitium API Token Setup

## Overview

Each Technitium DNS server should have its **own unique API token**. This is the recommended approach until Technitium adds native clustering support in a future release.

Tokens are stored in `inventory/raclette/host_vars/technitium-dns*.yml`.

## Generate API Tokens

### Via Web UI (Recommended)

Generate a **unique token for each server**:

#### DNS Server 1 (192.168.20.29)

1. Log into: http://192.168.20.29:5380
2. Navigate to: **Settings → API**
3. Click **"Generate Token"**
4. Copy the token
5. Update `inventory/raclette/host_vars/technitium-dns1.yml`:
   ```yaml
   technitium:
     api_token: "YOUR_TOKEN_HERE"
   ```

#### DNS Server 2 (192.168.20.28)

1. Log into: http://192.168.20.28:5380
2. Navigate to: **Settings → API**
3. Click **"Generate Token"** (generate a NEW token, don't reuse dns1's)
4. Copy the token
5. Update `inventory/raclette/host_vars/technitium-dns2.yml`:
   ```yaml
   technitium:
     api_token: "YOUR_TOKEN_HERE"
   ```

### Via API

```bash
# Generate unique token on each server
curl -X POST "http://192.168.20.29:5380/api/user/createToken?user=admin&pass=YOUR_PASSWORD&tokenName=automation-dns1"
curl -X POST "http://192.168.20.28:5380/api/user/createToken?user=admin&pass=YOUR_PASSWORD&tokenName=automation-dns2"
```

## Security: Use Ansible Vault (Recommended)

Since API tokens are sensitive, encrypt them with Ansible Vault:

```bash
cd /mnt/d/cluster/monger-homelab

# Encrypt the host_vars files
ansible-vault encrypt inventory/raclette/host_vars/technitium-dns1.yml
ansible-vault encrypt inventory/raclette/host_vars/technitium-dns2.yml

# When running playbooks, use --ask-vault-pass
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_api_backup.yml --ask-vault-pass

# Or store vault password in a file (keep secure!)
echo "your-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_api_backup.yml --vault-password-file ~/.vault_pass
```

## Verify Token Works

```bash
# Test API access
curl "http://192.168.20.29:5380/api/settings/backup?token=YOUR_TOKEN" -o test-backup.zip

# Should download a backup.zip file
ls -lh test-backup.zip
rm test-backup.zip
```

## Update Existing Servers

If your servers currently have different tokens, you need to synchronize them:

### Method 1: Regenerate on Primary, Copy to Secondary

```bash
# On dns1 - generate new token via UI
# Copy the token

# On dns2 - delete old token, add new one
# Settings → API → Delete old token → Add token with same value as dns1
```

### Method 2: Use Ansible to Sync (Future Enhancement)

We could create a playbook to sync API tokens, but manual sync via UI is simpler for now.

## Security Best Practices

1. **Rotate tokens periodically** (every 90 days)
2. **Use Ansible Vault** for production
3. **Limit token permissions** if Technitium supports it
4. **Never commit tokens to git** (use environment variables or vault)

## Testing Backups

```bash
# Test backup with token
ssh james@192.168.20.50
sudo su - automation
cd /opt/automation/monger-homelab

# Set token
export TECHNITIUM_API_TOKEN="your-token-here"

# Run backup
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_api_backup.yml

# Check backups
ls -lh /mnt/unraid-backups/technitium/
```

## Troubleshooting

### "Unauthorized" or "Invalid token"
- Token is incorrect or expired
- Regenerate token and update environment variable

### "Token not found"
- Environment variable not set
- Run: `export TECHNITIUM_API_TOKEN="your-token"`

### Different tokens on each server
- Synchronize tokens manually via web UI
- All servers must use the SAME token

## Related Files

- `group_vars/all.yml` - Token configuration
- `playbook/technitium_api_backup.yml` - Backup playbook using token
- `terraform/vars.tf` - Legacy per-host tokens (deprecated)

---

**Last Updated**: 2025-10-20  
**Maintained By**: Infrastructure Team
