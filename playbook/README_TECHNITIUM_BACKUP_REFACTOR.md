# Technitium Backup Refactoring - API-Based Backups

## Overview
This refactoring moves from file-based backups to using Technitium's native backup API with secure token management via Ansible Vault.

## What Changed

### Before (Old Method)
- Copied files directly from `/etc/dns` or Docker containers
- Used `docker cp` or `cp -r` commands
- Created `.tar.gz` archives
- Required root/sudo access
- Fragile - depended on filesystem layout

### After (New Method)
- Uses Technitium's native `/api/settings/backup` endpoint
- Creates proper `.zip` backups (same format as UI)
- API tokens stored securely in Ansible Vault
- No root access needed on target servers
- Backups can be restored via Technitium UI

## Files Changed

### New Files
- `inventory/raclette/group_vars/technitium_dns.yml` - Group variables
- `inventory/raclette/host_vars/technitium-dns1.yml` - Host-specific token
- `inventory/raclette/host_vars/technitium-dns2.yml` - Host-specific token
- `playbook/README_TECHNITIUM_API_SETUP.md` - API setup guide
- `playbook/README_TECHNITIUM_BACKUP_REFACTOR.md` - This file
- `scripts/add_technitium_tokens_to_vault.sh` - Helper script

### Modified Files
- `playbook/technitium_daily_backup.yml` - Now uses API method
- `playbook/technitium_api_backup.yml` - Updated to use vault tokens
- `playbook/configure_dhcp_api.yml` - Now uses vault tokens
- `playbook/configure_dns_zones.yml` - Now uses vault tokens

### Backup Files (for reference)
- `playbook/technitium_daily_backup_old.yml` - Old file-based method

## Setup Instructions

### Step 1: Add Tokens to Vault

The API tokens are currently hardcoded in the old playbooks:
- `technitium-dns1`: `f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8`
- `technitium-dns2`: `819048ea9356f23157ab915dc4e8f9e2927ccaa206a207f61982c41da8842615`

Edit the vault and add these tokens:

```bash
cd /mnt/d/cluster/monger-homelab
ansible-vault edit inventory/raclette/group_vars/vault.yml
```

Add this content to the vault:

```yaml
# Technitium DNS API Tokens
vault_technitium_tokens:
  technitium-dns1: "f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8"
  technitium-dns2: "819048ea9356f23157ab915dc4e8f9e2927ccaa206a207f61982c41da8842615"
```

### Step 2: Verify Configuration

Check that all files are in place:

```bash
# Check group vars
ls -l inventory/raclette/group_vars/
# Should show: technitium_dns.yml, vault.yml

# Check host vars
ls -l inventory/raclette/host_vars/
# Should show: technitium-dns1.yml, technitium-dns2.yml

# Check playbooks
ls -l playbook/technitium*.yml
```

### Step 3: Test Token Loading (Dry Run)

Test that tokens are loaded correctly without making changes:

```bash
cd /mnt/d/cluster/monger-homelab

# Test with vault password prompt
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --ask-vault-pass \
  --check

# Or with vault password file
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --vault-password-file ~/.vault_pass \
  --check
```

### Step 4: Test Backup (Single Server)

Test backup on one server first:

```bash
# Backup only technitium-dns1
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --ask-vault-pass \
  --limit technitium-dns1
```

Expected output:
```
TASK [Display backup location]
ok: [technitium-dns1] => {
    "msg": "✅ Backup saved to /mnt/unraid-backups/technitium/technitium-dns1-2025-01-20-1430.zip"
}
```

### Step 5: Verify Backup File

Check that the backup was created:

```bash
# List recent backups
ls -lh /mnt/unraid-backups/technitium/*.zip | tail -5

# Check backup size (should be several MB)
du -h /mnt/unraid-backups/technitium/technitium-dns1-*.zip | tail -1
```

### Step 6: Test Backup Restore (Optional)

To verify the backup is valid, you can restore it via the Technitium UI:

1. Log into Technitium: `http://192.168.20.29:5380`
2. Go to **Settings** → **Backup & Restore**
3. Click **Choose File** and select the backup `.zip` file
4. Click **Restore**
5. Verify settings are restored correctly

**⚠️ WARNING**: Restore will overwrite current configuration. Only test on a non-production server or take a backup first!

### Step 7: Run Full Backup

Once verified, run backup for all servers:

```bash
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --ask-vault-pass
```

## Automation Setup

### Option 1: Cron (Recommended)

Create a vault password file (one-time setup):

```bash
# Create password file (secure it!)
echo "your_vault_password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

Add to crontab:

```bash
crontab -e

# Add this line for daily backups at 2 AM
0 2 * * * cd /mnt/d/cluster/monger-homelab && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml --vault-password-file ~/.vault_pass >> /tmp/technitium-backup.log 2>&1
```

### Option 2: Systemd Timer

Create `/etc/systemd/system/technitium-backup.service`:

```ini
[Unit]
Description=Technitium DNS Backup
After=network.target

[Service]
Type=oneshot
User=your_user
WorkingDirectory=/mnt/d/cluster/monger-homelab
ExecStart=/usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml --vault-password-file /home/your_user/.vault_pass
StandardOutput=journal
StandardError=journal
```

Create `/etc/systemd/system/technitium-backup.timer`:

```ini
[Unit]
Description=Daily Technitium DNS Backup
Requires=technitium-backup.service

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable technitium-backup.timer
sudo systemctl start technitium-backup.timer

# Check status
sudo systemctl status technitium-backup.timer
sudo systemctl list-timers | grep technitium
```

## Troubleshooting

### Error: "API token not found"

**Cause**: Token not loaded from vault or host_vars missing

**Fix**:
1. Verify vault contains `vault_technitium_tokens`
2. Check host_vars files exist for each server
3. Ensure vault is decrypted during playbook run

```bash
# Test variable loading
ansible -i inventory/raclette/inventory.ini technitium-dns1 \
  -m debug -a "var=technitium_api_token" \
  --ask-vault-pass
```

### Error: "HTTP 401 Unauthorized"

**Cause**: Invalid or expired API token

**Fix**:
1. Generate new token in Technitium UI (Settings → API)
2. Update vault with new token
3. Re-run playbook

### Error: "Connection refused"

**Cause**: Technitium service not running or wrong port

**Fix**:
1. Check service status: `docker ps | grep technitium`
2. Verify port: `curl http://192.168.20.29:5380`
3. Check firewall rules

### Error: "Backup file not found"

**Cause**: API call succeeded but file wasn't created

**Fix**:
1. Check disk space on target server: `df -h /tmp`
2. Check Technitium logs: `docker logs technitium`
3. Verify API endpoint: `curl -X POST "http://192.168.20.29:5380/api/settings/backup" -d "token=YOUR_TOKEN" -o test.zip`

### Error: "Permission denied" on Unraid mount

**Cause**: Unraid NFS/SMB mount not accessible

**Fix**:
1. Verify mount: `ls -l /mnt/unraid-backups/technitium`
2. Check mount status: `mount | grep unraid`
3. Re-mount if needed: `sudo mount -a`

## Backup Retention

Backups are automatically cleaned up after 30 days (configurable in `group_vars/technitium_dns.yml`).

To change retention:

```yaml
# inventory/raclette/group_vars/technitium_dns.yml
backup_retention_days: 60  # Keep for 60 days
```

## Manual Backup Commands

### Backup Single Server
```bash
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --ask-vault-pass \
  --limit technitium-dns1
```

### Backup All Servers
```bash
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --ask-vault-pass
```

### Skip Cleanup (Keep Old Backups)
```bash
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_daily_backup.yml \
  --ask-vault-pass \
  --skip-tags cleanup
```

## API Endpoints Reference

### Backup
```bash
# Create backup
curl -X POST "http://server:5380/api/settings/backup" \
  -d "token=YOUR_TOKEN" \
  -o backup.zip
```

### Restore
```bash
# Restore from backup
curl -X POST "http://server:5380/api/settings/restore" \
  -F "token=YOUR_TOKEN" \
  -F "file=@backup.zip"
```

### List Zones (Test Token)
```bash
# Test if token works
curl -X GET "http://server:5380/api/zones/list?token=YOUR_TOKEN"
```

## Security Best Practices

1. **Rotate tokens regularly** (every 90 days recommended)
2. **Use vault password file** with restricted permissions (600)
3. **Never commit vault.yml unencrypted** to git
4. **Limit token permissions** if Technitium supports it
5. **Monitor backup logs** for failures
6. **Test restores periodically** to ensure backups are valid

## Migration from Old Method

If you have existing `.tar.gz` backups from the old method:

1. Keep old backups for reference
2. New `.zip` backups are NOT compatible with old `.tar.gz` format
3. To restore old backups, use the old playbook: `technitium_daily_backup_old.yml`
4. Going forward, only `.zip` backups will be created

## Next Steps

- [ ] Add tokens to vault
- [ ] Test backup on single server
- [ ] Verify backup file is valid
- [ ] Test restore (optional)
- [ ] Run full backup on all servers
- [ ] Set up automated backups (cron/systemd)
- [ ] Document vault password location
- [ ] Schedule token rotation reminder
- [ ] Test disaster recovery procedure

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Technitium API docs: https://technitium.com/dns/
3. Check Ansible logs: `/tmp/technitium-backup.log`
4. Verify vault decryption: `ansible-vault view inventory/raclette/group_vars/vault.yml`
