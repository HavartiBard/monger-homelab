# DNS Infrastructure Summary

## Current Legacy Infrastructure

### DNS Servers
- **dns1.lab.klsll.com**: 192.168.20.3 (VM 100) on pve1
  - Primary DNS server
  - DHCP server for VLAN 20 (192.168.20.0/24 - Homelab)
  - DHCP server for VLAN 30 (192.168.30.0/24 - IoT)
  - Production critical ⚠️

- **dns2.lab.klsll.com**: 192.168.20.2 (VM ?) on pve2
  - Secondary DNS server
  - Role: To be documented

## New Technitium Infrastructure

### DNS Servers (Deployed)
- **technitium-dns1**: 192.168.20.29 (VM 105) on pve1
  - Ubuntu 24.04 LTS
  - Docker-based Technitium DNS (latest)
  - 1GB RAM, 2 cores, 10GB disk
  - Status: ✅ Deployed and running

- **technitium-dns2**: 192.168.20.28 (VM 106) on pve2
  - Ubuntu 24.04 LTS
  - Docker-based Technitium DNS (latest)
  - 1GB RAM, 2 cores, 10GB disk
  - Status: ✅ Deployed and running

## Network Configuration

### VLANs
- **VLAN 20**: 192.168.20.0/24 - Homelab
  - Gateway: 192.168.20.1
  - DNS: 192.168.20.3, 192.168.20.2 (legacy)
  - DHCP: 192.168.20.3 (dns1)
  
- **VLAN 30**: 192.168.30.0/24 - IoT
  - Gateway: 192.168.30.1
  - DNS: 192.168.20.3, 192.168.20.2 (legacy)
  - DHCP: 192.168.20.3 (dns1)

### Key Infrastructure IPs (VLAN 20)
- 192.168.20.1: Gateway/Router
- 192.168.20.2: dns2.lab.klsll.com (legacy)
- 192.168.20.3: dns1.lab.klsll.com (legacy)
- 192.168.20.28: technitium-dns2 (new)
- 192.168.20.29: technitium-dns1 (new)
- 192.168.20.100: pve1 (Proxmox)
- 192.168.20.101: pve2 (Proxmox)

## Backup Strategy

### Daily Automated Backups
- **Target**: Unraid NAS
- **Frequency**: Daily at 2:00 AM (configurable)
- **Retention**: 30 days
- **Servers backed up**:
  - dns1 (192.168.20.3)
  - dns2 (192.168.20.2)
  - technitium-dns1 (192.168.20.29)
  - technitium-dns2 (192.168.20.28)

### Backup Contents
- Complete DNS zones and records
- DHCP configuration (scopes, reservations)
- Forwarders and settings
- Blocklists and ACLs
- Admin credentials

### Setup Required
1. Mount Unraid NAS share to Ansible control machine
2. Update `technitium_daily_backup.yml` with Unraid path
3. Set up cron job for daily execution
4. Test backup and restore procedures

See: `README_AUTOMATED_BACKUPS.md`

## Migration Status

### Completed ✅
- [x] New DNS VMs deployed via Terraform
- [x] Ansible playbook for Technitium installation
- [x] Bootstrap configuration (Docker, system packages)
- [x] Technitium DNS containers running
- [x] systemd-resolved disabled (port 53 freed)
- [x] Inventory updated with all servers
- [x] Backup/restore playbooks created
- [x] Daily backup automation configured
- [x] Migration plan documented

### In Progress 🔄
- [ ] Change admin passwords on new servers
- [ ] Backup legacy DNS configuration
- [ ] Restore configuration to new servers
- [ ] Configure DNS zones and forwarders
- [ ] Set up zone replication

### Pending ⏳
- [ ] Add new DNS as secondary in DHCP
- [ ] Configure DHCP scopes (VLAN 20 + VLAN 30)
- [ ] Test DHCP failover
- [ ] DHCP cutover (maintenance window)
- [ ] Decommission legacy servers

## Quick Commands

### Test Connectivity
```bash
# Ping all DNS servers
ansible -i inventory/raclette/inventory.ini dns_old,technitium_dns -m ping

# Check Technitium status
ssh james@192.168.20.29 "docker ps | grep technitium"
ssh james@192.168.20.28 "docker ps | grep technitium"
```

### Backup & Restore
```bash
cd /mnt/d/cluster/monger-homelab

# One-time migration backup/restore
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml

# Daily automated backup
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml
```

### DNS Testing
```bash
# Test DNS resolution
dig @192.168.20.3 google.com    # Legacy dns1
dig @192.168.20.2 google.com    # Legacy dns2
dig @192.168.20.29 google.com   # New technitium-dns1
dig @192.168.20.28 google.com   # New technitium-dns2

# Test local domain
dig @192.168.20.29 pve1.lab.klsll.com
```

### Web Interfaces
- **Legacy dns1**: http://192.168.20.3:5380
- **Legacy dns2**: http://192.168.20.2:5380
- **New dns1**: http://192.168.20.29:5380
- **New dns2**: http://192.168.20.28:5380

## Documentation Files

### Migration & Planning
- `DNS_MIGRATION_PLAN.md` - Complete 4-week migration guide
- `DNS_DEPLOYMENT.md` - Initial deployment notes
- `QUICKSTART_DNS_MIGRATION.md` - Quick reference

### Playbooks
- `technitium_dns.yml` - Initial deployment playbook
- `technitium_backup_restore.yml` - One-time migration backup/restore
- `technitium_daily_backup.yml` - Daily automated backups

### Documentation
- `README_TECHNITIUM.md` - Technitium deployment guide
- `README_BACKUP_RESTORE.md` - Backup/restore detailed guide
- `README_AUTOMATED_BACKUPS.md` - Daily backup setup guide
- `DNS_SETUP_SUMMARY.md` - This file

## Next Steps

### Immediate (This Week)
1. ⚠️ **Change admin passwords** on new servers
2. 📦 **Set up Unraid NAS mount** for backups
3. 🔄 **Run initial backup** from legacy servers
4. ✅ **Restore to new servers**
5. 🧪 **Test DNS resolution** on new servers

### Week 1-2
1. Add new DNS as secondary in DHCP
2. Monitor DNS query distribution
3. Configure DHCP scopes (don't enable yet)
4. Set up zone replication

### Week 3-4
1. DHCP cutover (maintenance window)
2. Monitor for issues
3. Decommission legacy servers

See `DNS_MIGRATION_PLAN.md` for detailed timeline.

## Support & Troubleshooting

### Common Issues
- **Port 53 in use**: systemd-resolved disabled on new servers
- **Backup fails**: Check SSH connectivity and Docker status
- **DNS not resolving**: Wait 30-60s after container start
- **DHCP conflicts**: Ensure only one DHCP server active per VLAN

### Getting Help
1. Check playbook logs: `/tmp/dns-backup.log`
2. Review container logs: `docker logs technitium`
3. Test connectivity: `ansible -m ping`
4. Verify services: `docker ps`, `netstat -tulpn`

## Important Reminders

⚠️ **DO NOT enable DHCP on new servers until cutover**
⚠️ **Change default admin passwords immediately**
⚠️ **Test backups regularly**
⚠️ **Keep old servers running until new ones proven stable**
⚠️ **Document any custom DNS records before migration**

---

Last Updated: 2025-01-16
Status: New servers deployed, ready for configuration
