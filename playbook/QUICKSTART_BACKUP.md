# Technitium Backup - Quick Start Guide

## Prerequisites
- Ansible installed
- Vault password
- Unraid NFS mount at `/mnt/unraid-backups/technitium`

## One-Time Setup

### 1. Add Tokens to Vault
```bash
cd /mnt/d/cluster/monger-homelab
ansible-vault edit inventory/raclette/group_vars/vault.yml
```

Add this content:
```yaml
# Technitium DNS API Tokens
vault_technitium_tokens:
  technitium-dns1: "f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8"
  technitium-dns2: "819048ea9356f23157ab915dc4e8f9e2927ccaa206a207f61982c41da8842615"
```

### 2. Create Vault Password File (Optional)
```bash
echo "your_vault_password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

## Running Backups

### Manual Backup (All Servers)
```bash
cd /mnt/d/cluster/monger-homelab

# With password prompt
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --ask-vault-pass

# With password file
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --vault-password-file ~/.vault_pass
```

### Backup Single Server
```bash
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --vault-password-file ~/.vault_pass \
  --limit technitium-dns1
```

## Automated Backups

### Setup Cron (Daily at 2 AM)
```bash
crontab -e

# Add this line
0 2 * * * cd /mnt/d/cluster/monger-homelab && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml --vault-password-file ~/.vault_pass >> /tmp/technitium-backup.log 2>&1
```

## Verify Backups

### List Recent Backups
```bash
ls -lh /mnt/unraid-backups/technitium/*.zip | tail -10
```

### Check Backup Size
```bash
du -sh /mnt/unraid-backups/technitium/
```

### View Backup Summary
The playbook automatically displays a summary at the end:
```
========================================
Technitium DNS Backup Summary
========================================
Total Backups: 15
Total Size: 45M
Location: /mnt/unraid-backups/technitium
Retention: 30 days
========================================
```

## Restore Backup

### Via Technitium UI (Recommended)
1. Go to `http://192.168.20.29:5380`
2. Login with admin credentials
3. Navigate to **Settings** → **Backup & Restore**
4. Click **Choose File** and select backup `.zip`
5. Click **Restore**
6. Wait for restore to complete
7. Verify settings

### Via API (Advanced)
```bash
curl -X POST "http://192.168.20.29:5380/api/settings/restore" \
  -F "token=YOUR_TOKEN" \
  -F "file=@/path/to/backup.zip"
```

## Troubleshooting

### Check if tokens are loaded
```bash
ansible -i inventory/raclette/inventory.ini technitium-dns1 \
  -m debug -a "var=technitium_api_token" \
  --ask-vault-pass
```

### Test API connection
```bash
# Test backup endpoint
curl -X POST "http://192.168.20.29:5380/api/settings/backup" \
  -d "token=f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8" \
  -o test-backup.zip

# Check if file was created
ls -lh test-backup.zip
```

### View cron logs
```bash
tail -f /tmp/technitium-backup.log
```

## Files Overview

### Configuration Files
- `inventory/raclette/group_vars/technitium_dns.yml` - Group settings
- `inventory/raclette/group_vars/vault.yml` - Encrypted tokens
- `inventory/raclette/host_vars/technitium-dns1.yml` - Server 1 config
- `inventory/raclette/host_vars/technitium-dns2.yml` - Server 2 config

### Playbooks
- `playbook/technitium_daily_backup.yml` - Main backup playbook (API-based)
- `playbook/technitium_daily_backup_old.yml` - Old file-based method (deprecated)
- `playbook/technitium_api_backup.yml` - Alternative API backup (same as daily)

### Documentation
- `playbook/README_TECHNITIUM_BACKUP_REFACTOR.md` - Full refactoring guide
- `playbook/README_TECHNITIUM_API_SETUP.md` - API setup details
- `playbook/QUICKSTART_BACKUP.md` - This file

## Common Commands

```bash
# Backup all servers
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml --vault-password-file ~/.vault_pass

# Backup one server
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml --vault-password-file ~/.vault_pass --limit technitium-dns1

# Dry run (check mode)
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml --vault-password-file ~/.vault_pass --check

# View vault
ansible-vault view inventory/raclette/group_vars/vault.yml

# Edit vault
ansible-vault edit inventory/raclette/group_vars/vault.yml

# List backups
ls -lh /mnt/unraid-backups/technitium/

# Check backup age
find /mnt/unraid-backups/technitium/ -name "*.zip" -mtime -7 -ls

# Manual cleanup (remove backups older than 30 days)
find /mnt/unraid-backups/technitium/ -name "*.zip" -mtime +30 -delete
```

## Backup Schedule

- **Frequency**: Daily at 2:00 AM (configurable)
- **Retention**: 30 days (configurable)
- **Location**: `/mnt/unraid-backups/technitium/`
- **Format**: `.zip` (Technitium native format)
- **Naming**: `{hostname}-{YYYY-MM-DD-HHMM}.zip`

## Support

For detailed documentation, see:
- `README_TECHNITIUM_BACKUP_REFACTOR.md` - Complete guide
- `README_TECHNITIUM_API_SETUP.md` - API configuration
- `README_AUTOMATED_BACKUPS.md` - Automation setup
