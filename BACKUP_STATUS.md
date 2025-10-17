# DNS Backup Status

## Current State

✅ **Backup Playbook**: `playbook/technitium_daily_backup.yml` exists  
❓ **Automated Backups**: Not yet enabled (needs setup)  
✅ **Documentation**: Comprehensive guides available  

## Quick Setup

### Enable Daily Backups (One-Time Setup)

```bash
cd /mnt/d/cluster/monger-homelab

# Run the setup script
bash scripts/enable_daily_backups.sh
```

This will:
1. Mount Unraid NFS share
2. Test manual backup
3. Setup daily cron job (2 AM)

### Check Backup Status

```bash
# Check if backups are running
bash scripts/check_backup_status.sh

# View recent backups
ls -lht /mnt/unraid-backups/technitium/ | head -10

# Check cron job
crontab -l | grep technitium
```

## What Gets Backed Up

For each DNS server (dns1, dns2):
- ✅ **DNS Zones** - All forward and reverse zones
- ✅ **DNS Records** - A, CNAME, PTR, etc.
- ✅ **DHCP Config** - Scopes, reservations, failover
- ✅ **Settings** - Forwarders, blocklists, ACLs
- ✅ **Credentials** - Admin passwords
- ✅ **Metadata** - Hostname, IP, timestamp

## Backup Details

| Setting | Value |
|---------|-------|
| **Frequency** | Daily at 2:00 AM |
| **Retention** | 30 days |
| **Location** | `/mnt/unraid-backups/technitium/` |
| **Format** | `.tar.gz` compressed archives |
| **Size** | ~10-50 MB per backup |
| **Naming** | `{hostname}-{date}-{time}.tar.gz` |

## Recovery

### Quick Restore

```bash
# 1. Find latest backup
ls -lt /mnt/unraid-backups/technitium/ | head

# 2. Extract backup
tar -xzf /mnt/unraid-backups/technitium/dns1-2025-10-17-0200.tar.gz -C /tmp/

# 3. Stop Technitium
ssh james@192.168.20.29 "docker stop technitium"

# 4. Restore data
scp -r /tmp/technitium-backup-*/dns-data/* james@192.168.20.29:/opt/technitium/

# 5. Start Technitium
ssh james@192.168.20.29 "docker start technitium"
```

### Full Restore Playbook

```bash
# Use the automated restore playbook
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml
```

## Monitoring

### Daily Checks

```bash
# Check backup status
bash scripts/check_backup_status.sh

# View logs
tail -f /tmp/dns-backup.log
```

### Weekly Verification

1. Verify backups are being created
2. Check backup sizes are reasonable
3. Test restore to a test VM (monthly)

### Alerts (Optional)

Add email notifications to cron:

```bash
crontab -e

# Add email on failure
0 2 * * * cd /mnt/d/cluster/monger-homelab && ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml || echo "DNS backup failed!" | mail -s "Backup Alert" you@example.com
```

## Disaster Recovery Plan

### Scenario 1: Single Server Failure

1. Deploy new VM via Terraform
2. Install Technitium via Ansible
3. Restore from latest backup
4. Verify DNS resolution
5. Update DHCP failover config

### Scenario 2: Both Servers Lost

1. Deploy both VMs via Terraform
2. Install Technitium on both
3. Restore from latest backups
4. Reconfigure DHCP failover
5. Test DNS and DHCP

### Scenario 3: Backup System Failure

Your IaC configs are the fallback:
1. Deploy VMs via Terraform
2. Install Technitium via Ansible
3. Deploy DNS zones: `ansible-playbook playbook/configure_dns_zones.yml`
4. Deploy DHCP: `ansible-playbook playbook/configure_dhcp_api.yml`
5. Manually configure any custom settings

## Best Practices

✅ **Test restores monthly** - Verify backups are valid  
✅ **Monitor backup success** - Check logs weekly  
✅ **Keep IaC updated** - DNS/DHCP configs in Git  
✅ **Document changes** - Update configs when making manual changes  
✅ **Offsite copy** - Consider syncing to cloud storage  

## Files Reference

- **Setup**: `scripts/enable_daily_backups.sh`
- **Status**: `scripts/check_backup_status.sh`
- **Backup Playbook**: `playbook/technitium_daily_backup.yml`
- **Restore Playbook**: `playbook/technitium_backup_restore.yml`
- **Full Guide**: `playbook/README_AUTOMATED_BACKUPS.md`

## Next Steps

1. **Enable backups**: Run `scripts/enable_daily_backups.sh`
2. **Verify tomorrow**: Check backups were created
3. **Test restore**: Practice recovery procedure
4. **Document**: Note any custom configurations not in IaC

---

## Summary

Your backup strategy has **two layers**:

1. **Infrastructure as Code** (Primary)
   - DNS zones: `config/dns_zones.yml`
   - DHCP scopes: `config/dhcp_scopes.yml`
   - Deployment: Ansible playbooks
   - Version controlled in Git

2. **Full Backups** (Secondary)
   - Complete Technitium state
   - Daily automated backups
   - 30-day retention
   - Stored on Unraid NAS

This gives you both **reproducible infrastructure** and **point-in-time recovery**! 🎯
