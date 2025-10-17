# Technitium DNS Backup & Restore

## Overview
Ansible playbook to backup configuration from old dns1 server and restore to new Technitium DNS servers.

## Prerequisites
1. SSH access to old dns1 server
2. New Technitium DNS servers deployed and accessible
3. Ansible installed on control machine

## Step 1: Update Inventory

Add your old dns1 server to `inventory/raclette/inventory.ini`:

```ini
[dns_old]
dns1 ansible_host=<OLD_DNS1_IP> ansible_user=james

[technitium_dns]
technitium-dns1 ansible_host=192.168.20.29 ansible_user=james
technitium-dns2 ansible_host=192.168.20.28 ansible_user=james
```

**⚠️ Replace `<OLD_DNS1_IP>` with the actual IP of your old dns1 server (VM 100)**

## Step 2: Run Backup & Restore

### Full Backup and Restore (Recommended)
```bash
cd /mnt/d/cluster/monger-homelab

# Run complete backup and restore
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml
```

This will:
1. ✅ Backup configuration from old dns1
2. ✅ Save backup locally to `./technitium-backup-YYYY-MM-DD/`
3. ✅ Restore configuration to both new servers
4. ✅ Restart Technitium containers
5. ✅ Verify services are running

### Backup Only
```bash
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml --tags backup
```

### Restore Only (if you already have a backup)
```bash
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml --tags restore
```

## What Gets Backed Up

The playbook backs up the entire Technitium data directory, which includes:

- **DNS Zones**: All configured zones (forward and reverse)
- **DNS Records**: A, AAAA, CNAME, MX, TXT, etc.
- **DHCP Configuration**: Scopes, reservations, options
- **Forwarders**: Upstream DNS server configuration
- **Settings**: Server settings, logging, etc.
- **Blocklists**: Any configured blocklists
- **Allowed/Blocked zones**: Access control lists

## Post-Restore Steps

After restore completes:

1. **Log into web interfaces** (use your existing credentials):
   - http://192.168.20.29:5380
   - http://192.168.20.28:5380

2. **Verify DNS zones** are present:
   - Check all zones loaded correctly
   - Verify DNS records

3. **Check DHCP configuration**:
   - Verify scopes are configured
   - Check reservations
   - **DO NOT ENABLE DHCP YET** (follow migration plan)

4. **Test DNS resolution**:
   ```bash
   dig @192.168.20.29 google.com
   dig @192.168.20.28 google.com
   dig @192.168.20.29 <your-local-domain>
   ```

5. **Set up zone replication** between dns1 and dns2:
   - In web UI: Zones → Select zone → Settings
   - Configure secondary server for zone transfer

## Troubleshooting

### Backup fails with "container not found"
- Old dns1 might not be running Technitium in Docker
- Check if it's a native installation at `/etc/dns`
- Playbook handles both cases automatically

### Restore fails with "backup file not found"
- Ensure backup completed successfully first
- Check `./technitium-backup-YYYY-MM-DD/` directory exists
- Verify `technitium-backup.tar.gz` is present

### Container won't start after restore
```bash
# Check container logs
ssh james@192.168.20.29 "docker logs technitium"

# Check data directory permissions
ssh james@192.168.20.29 "ls -la /opt/technitium"

# Restart container
ssh james@192.168.20.29 "docker restart technitium"
```

### DNS not resolving after restore
- Wait 30-60 seconds for Technitium to fully start
- Check container is running: `docker ps | grep technitium`
- Verify port 53 is listening: `netstat -tulpn | grep :53`
- Check logs for errors

## Manual Backup (Alternative Method)

If you prefer manual backup via web UI:

1. Log into old dns1 web interface
2. Settings → Backup
3. Download backup file
4. Log into new servers
5. Settings → Restore
6. Upload backup file

**Note**: Ansible method is faster and ensures consistency across both servers.

## Backup Location

Backups are saved to:
```
./technitium-backup-YYYY-MM-DD/technitium-backup.tar.gz
```

**⚠️ Keep this backup safe!** It contains your entire DNS/DHCP configuration.

## Important Notes

### About DHCP After Restore:
- DHCP configuration will be restored but **disabled by default**
- Follow the migration plan before enabling DHCP
- Do NOT enable DHCP on new servers while old dns1 is still serving DHCP

### About Admin Credentials:
- Restored servers will use the **same admin credentials** as old dns1
- If you changed passwords on new servers, they will be overwritten
- You can change passwords after restore

### About IP Addresses:
- Configuration is IP-agnostic for most settings
- DHCP scopes will be restored as-is
- Update any IP-specific settings after restore if needed

## Next Steps

After successful backup and restore:

1. ✅ Follow `DNS_MIGRATION_PLAN.md` for cutover
2. ✅ Test DNS resolution thoroughly
3. ✅ Configure zone replication
4. ✅ Plan DHCP cutover maintenance window

## See Also

- `DNS_MIGRATION_PLAN.md` - Complete 4-week migration guide
- `README_TECHNITIUM.md` - Technitium deployment guide
- `technitium_dns.yml` - Initial deployment playbook
