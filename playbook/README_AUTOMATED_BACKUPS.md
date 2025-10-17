# Automated Daily Backups to Unraid NAS

## Overview
Automated daily backups of all Technitium DNS servers (legacy and new) to your Unraid NAS with 30-day retention.

## Prerequisites

### 1. Unraid NAS Share Setup
You need to decide how to access your Unraid NAS. Choose **ONE** method:

#### Option A: NFS Mount (Recommended)
```bash
# On your Ansible control machine (WSL)
sudo mkdir -p /mnt/unraid-backups
sudo apt install -y nfs-common

# Add to /etc/fstab for persistent mount
echo "192.168.20.X:/mnt/user/backups /mnt/unraid-backups nfs defaults 0 0" | sudo tee -a /etc/fstab

# Mount now
sudo mount -a
```

#### Option B: SMB/CIFS Mount
```bash
# On your Ansible control machine (WSL)
sudo mkdir -p /mnt/unraid-backups
sudo apt install -y cifs-utils

# Create credentials file
sudo nano /root/.smbcredentials
# Add:
# username=your_unraid_user
# password=your_unraid_password

# Add to /etc/fstab
echo "//192.168.20.X/backups /mnt/unraid-backups cifs credentials=/root/.smbcredentials,uid=1000,gid=1000 0 0" | sudo tee -a /etc/fstab

# Mount now
sudo mount -a
```

#### Option C: SSH/SCP (No mount needed)
If you prefer, the playbook can be modified to use SCP directly to Unraid.

### 2. Update Playbook Variables

Edit `playbook/technitium_daily_backup.yml` and update:

```yaml
vars:
  unraid_backup_path: "/mnt/unraid-backups/technitium"  # Your mount point
  backup_retention_days: 30  # How many days to keep backups
```

**Replace with your actual Unraid IP:**
- In the NFS/SMB mount commands above
- Or in the playbook if using SCP

## Manual Backup Test

Before setting up automation, test the backup manually:

```bash
cd /mnt/d/cluster/monger-homelab

# Run backup for all DNS servers
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml

# Check Unraid for backups
ls -lh /mnt/unraid-backups/technitium/
```

You should see files like:
```
dns1-2025-01-16-1430.tar.gz
dns2-2025-01-16-1430.tar.gz
technitium-dns1-2025-01-16-1430.tar.gz
technitium-dns2-2025-01-16-1430.tar.gz
```

## Automated Daily Backups

### Option 1: Cron on WSL (Recommended)

```bash
# Edit crontab
crontab -e

# Add this line to run daily at 2 AM
0 2 * * * cd /mnt/d/cluster/monger-homelab && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml >> /tmp/dns-backup.log 2>&1

# Or run every 6 hours
0 */6 * * * cd /mnt/d/cluster/monger-homelab && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml >> /tmp/dns-backup.log 2>&1
```

### Option 2: Windows Task Scheduler

Create a batch file `dns-backup.bat`:
```batch
@echo off
wsl bash -c "cd /mnt/d/cluster/monger-homelab && ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml"
```

Then create a scheduled task:
1. Open Task Scheduler
2. Create Basic Task
3. Trigger: Daily at 2:00 AM
4. Action: Start a program
5. Program: `C:\path\to\dns-backup.bat`

### Option 3: Ansible AWX/Tower (Advanced)

If you have AWX/Tower, create a scheduled job template.

## What Gets Backed Up

For each DNS server:
- ✅ Complete DNS configuration
- ✅ All DNS zones and records
- ✅ DHCP configuration (scopes, reservations)
- ✅ Forwarders and settings
- ✅ Blocklists and ACLs
- ✅ Admin credentials
- ✅ Backup metadata (hostname, IP, timestamp)

## Backup Retention

- **Default**: 30 days
- **Automatic cleanup**: Old backups are deleted automatically
- **Disk space**: ~10-50 MB per backup (depends on zone count)
- **Monthly usage**: ~1-2 GB for 4 servers with daily backups

## Restore from Backup

### Restore Specific Server
```bash
cd /mnt/d/cluster/monger-homelab

# Extract backup
tar -xzf /mnt/unraid-backups/technitium/dns1-2025-01-16-1430.tar.gz -C /tmp/

# Use the restore playbook (modify to point to extracted backup)
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml
```

### Emergency Restore
If you need to restore quickly:

1. **Find latest backup**:
   ```bash
   ls -lt /mnt/unraid-backups/technitium/ | head
   ```

2. **Extract to temp location**:
   ```bash
   tar -xzf /mnt/unraid-backups/technitium/dns1-YYYY-MM-DD-HHMM.tar.gz -C /tmp/restore/
   ```

3. **Copy to server**:
   ```bash
   ssh james@192.168.20.3 "sudo docker stop technitium"
   scp -r /tmp/restore/dns-data/* james@192.168.20.3:/opt/technitium/
   ssh james@192.168.20.3 "sudo docker start technitium"
   ```

## Monitoring

### Check Backup Status
```bash
# View recent backups
ls -lht /mnt/unraid-backups/technitium/ | head -10

# Check backup sizes
du -sh /mnt/unraid-backups/technitium/*

# View cron log
tail -f /tmp/dns-backup.log
```

### Backup Alerts (Optional)

Add to your cron job for email alerts:
```bash
0 2 * * * cd /mnt/d/cluster/monger-homelab && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml || echo "DNS backup failed!" | mail -s "DNS Backup Alert" your@email.com
```

Or use a monitoring tool like:
- Healthchecks.io
- Uptime Kuma
- Prometheus + Alertmanager

## Troubleshooting

### Mount not accessible
```bash
# Check if mounted
mount | grep unraid

# Try remounting
sudo umount /mnt/unraid-backups
sudo mount -a

# Check NFS/SMB service on Unraid
# Unraid Web UI → Shares → Enable NFS/SMB export
```

### Permission denied
```bash
# Check mount permissions
ls -la /mnt/unraid-backups/

# Fix ownership (if needed)
sudo chown -R $(whoami):$(whoami) /mnt/unraid-backups/technitium/
```

### Backup fails for specific server
```bash
# Test connectivity
ansible -i inventory/raclette/inventory.ini dns1 -m ping

# Check if Technitium is running
ssh james@192.168.20.3 "docker ps | grep technitium"

# Run playbook with verbose output
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml -vvv
```

### Disk space issues
```bash
# Check Unraid disk usage
df -h /mnt/unraid-backups/

# Reduce retention period in playbook
# Change: backup_retention_days: 30
# To: backup_retention_days: 7

# Manually cleanup old backups
find /mnt/unraid-backups/technitium/ -name "*.tar.gz" -mtime +7 -delete
```

## Best Practices

### 1. Test Restores Regularly
```bash
# Monthly: Test restore to a test VM
# Verify DNS zones and DHCP config are intact
```

### 2. Monitor Backup Success
- Check cron logs weekly
- Verify backups are being created
- Test random backup integrity monthly

### 3. Offsite Backups (Optional)
Consider syncing Unraid backups to cloud storage:
```bash
# Example: Sync to Backblaze B2
rclone sync /mnt/unraid-backups/technitium/ b2:my-bucket/dns-backups/
```

### 4. Document Recovery Procedures
Keep this README accessible offline in case of emergency.

## Backup Schedule Recommendations

| Environment | Frequency | Retention |
|-------------|-----------|-----------|
| Production | Every 6 hours | 30 days |
| Homelab | Daily | 14-30 days |
| Testing | Weekly | 7 days |

## Security Considerations

### Encrypt Backups (Optional)
```bash
# Modify playbook to encrypt backups
- name: Encrypt backup
  shell: |
    gpg --symmetric --cipher-algo AES256 {{ backup_dir }}.tar.gz
    rm {{ backup_dir }}.tar.gz
```

### Restrict Access
```bash
# Set restrictive permissions on Unraid share
# Unraid Web UI → Shares → technitium → Security
# Set to: Private (require authentication)
```

## Files Reference

- `technitium_daily_backup.yml` - Daily backup playbook
- `technitium_backup_restore.yml` - One-time migration backup/restore
- `DNS_MIGRATION_PLAN.md` - Complete migration guide
- `QUICKSTART_DNS_MIGRATION.md` - Quick reference

## Support

If backups fail consistently:
1. Check Ansible connectivity to all servers
2. Verify Unraid share is accessible
3. Check disk space on Unraid
4. Review playbook logs: `/tmp/dns-backup.log`
5. Test manual backup first

---

## Quick Reference Commands

```bash
# Manual backup now
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml

# List backups
ls -lht /mnt/unraid-backups/technitium/

# Check backup size
du -sh /mnt/unraid-backups/technitium/

# View cron jobs
crontab -l

# Test Unraid mount
df -h /mnt/unraid-backups/
```
