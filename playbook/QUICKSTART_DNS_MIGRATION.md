# DNS Migration Quick Start Guide

## TL;DR - Fast Track

### Step 1: Find Old DNS1 IP Address
```bash
# SSH into Proxmox and find VM 100
ssh james@192.168.20.100 "qm list | grep 100"
ssh james@192.168.20.100 "qm config 100 | grep -i ip"

# Or check DHCP leases / network scan
```

### Step 2: Update Inventory
Edit `inventory/raclette/inventory.ini`:
```ini
[dns_old]
dns1 ansible_host=<VM_100_IP_HERE> ansible_user=james
```

### Step 3: Run Backup & Restore
```bash
cd /mnt/d/cluster/monger-homelab

# One command does it all!
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml
```

### Step 4: Verify
```bash
# Test DNS on new servers
dig @192.168.20.29 google.com
dig @192.168.20.28 google.com

# Check web interfaces (use old dns1 credentials)
# http://192.168.20.29:5380
# http://192.168.20.28:5380
```

### Step 5: Follow Migration Plan
See `DNS_MIGRATION_PLAN.md` for complete 4-week cutover plan.

---

## What This Does

1. ✅ **Backs up** entire Technitium config from old dns1
   - DNS zones and records
   - DHCP configuration
   - Forwarders and settings
   - Blocklists and ACLs

2. ✅ **Restores** to both new servers
   - Identical configuration on both
   - Ready for zone replication
   - DHCP disabled (safe)

3. ✅ **Verifies** everything works
   - Containers running
   - DNS resolving
   - Web UI accessible

---

## Important Notes

### ⚠️ DHCP Will Be Disabled
- Configuration is restored but DHCP is **not enabled**
- This is intentional to prevent conflicts
- Follow migration plan before enabling DHCP

### 🔐 Credentials
- New servers will use **same credentials as old dns1**
- Any passwords you set on new servers will be overwritten
- This is expected behavior

### 💾 Backup Location
- Saved to: `./technitium-backup-YYYY-MM-DD/`
- Keep this safe as a rollback option

---

## Troubleshooting

### Can't find old dns1 IP?
```bash
# Check Proxmox VMs
ssh james@192.168.20.100 "qm list"
ssh james@192.168.20.101 "qm list"

# Check cloud-init config
ssh james@192.168.20.100 "qm cloudinit dump 100 network"

# Or just scan your network
nmap -sn 192.168.20.0/24
```

### Backup fails?
- Ensure SSH access to old dns1
- Check if Technitium is running: `docker ps` or check `/etc/dns`
- Verify you have sudo/root access

### Restore fails?
- Check new servers are accessible
- Verify Docker is running on new servers
- Ensure backup file exists locally

---

## Next Steps After Restore

1. **Week 1**: Test DNS resolution, add as secondary DNS
2. **Week 2**: Configure DHCP (but don't enable)
3. **Week 3**: DHCP cutover during maintenance window
4. **Week 4**: Decommission old server

See `DNS_MIGRATION_PLAN.md` for detailed timeline.

---

## Files Reference

- `technitium_backup_restore.yml` - The Ansible playbook
- `README_BACKUP_RESTORE.md` - Detailed documentation
- `DNS_MIGRATION_PLAN.md` - Complete 4-week migration guide
- `DNS_DEPLOYMENT.md` - Initial deployment notes
