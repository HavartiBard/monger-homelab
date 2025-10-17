# Complete DNS Infrastructure Setup Guide

## Overview
This guide will walk you through setting up:
1. ✅ Unraid NFS mount for backups
2. ✅ VLAN 30 interfaces on new DNS servers
3. ✅ Backup and restore legacy DNS configuration
4. ✅ Daily automated backups

---

## Step 1: Set Up Unraid NFS Mount (5 minutes)

### Run the setup script:
```bash
cd /mnt/d/cluster/monger-homelab

# Make script executable
chmod +x scripts/setup-unraid-mount.sh

# Run setup
./scripts/setup-unraid-mount.sh
```

This will:
- ✅ Install NFS client
- ✅ Mount Unraid at `/mnt/unraid-backups`
- ✅ Create backup directory
- ✅ Add to `/etc/fstab` for persistent mount
- ✅ Test write access

### Manual verification:
```bash
# Check mount
df -h | grep unraid

# Test write
echo "test" > /mnt/unraid-backups/technitium/test.txt
cat /mnt/unraid-backups/technitium/test.txt
rm /mnt/unraid-backups/technitium/test.txt
```

---

## Step 2: Configure VLAN 30 Interfaces (10 minutes)

### Important: Proxmox VLAN Configuration First!

Before running the Ansible playbook, ensure your Proxmox VMs are configured for VLAN tagging:

**On Proxmox host (pve1 and pve2):**
```bash
# For VM 105 (technitium-dns1) on pve1
ssh james@192.168.20.100
sudo qm set 105 -net0 virtio,bridge=vmbr0,tag=20
# Note: The VM's primary interface is already on VLAN 20

# For VM 106 (technitium-dns2) on pve2
ssh james@192.168.20.101
sudo qm set 106 -net0 virtio,bridge=vmbr0,tag=20
```

**OR** if you need the interface to be trunk (allow all VLANs):
```bash
# On pve1
sudo qm set 105 -net0 virtio,bridge=vmbr0,trunks=20;30

# On pve2
sudo qm set 106 -net0 virtio,bridge=vmbr0,trunks=20;30
```

### Run the VLAN 30 configuration playbook:
```bash
cd /mnt/d/cluster/monger-homelab

ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_vlan30.yml
```

This will:
- ✅ Install VLAN package
- ✅ Create VLAN 30 interface (ens18.30)
- ✅ Assign IP addresses:
  - technitium-dns1: 192.168.30.29
  - technitium-dns2: 192.168.30.28
- ✅ Configure routing
- ✅ Restart Technitium with host networking
- ✅ Test connectivity

### Verify VLAN 30 configuration:
```bash
# Check interfaces
ssh james@192.168.20.29 "ip addr show"
ssh james@192.168.20.28 "ip addr show"

# Test DNS on VLAN 30
dig @192.168.30.29 google.com
dig @192.168.30.28 google.com

# Test from VLAN 30 device (if you have one)
# ping 192.168.30.29
# ping 192.168.30.28
```

---

## Step 3: Backup and Restore Legacy DNS Config (15 minutes)

### Run the migration backup/restore:
```bash
cd /mnt/d/cluster/monger-homelab

ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml
```

This will:
1. ✅ Backup dns1 (192.168.20.3) configuration
2. ✅ Backup dns2 (192.168.20.2) configuration
3. ✅ Save backups locally with timestamp
4. ✅ Restore to technitium-dns1 (192.168.20.29)
5. ✅ Restore to technitium-dns2 (192.168.20.28)
6. ✅ Restart containers
7. ✅ Verify services

### Verify restoration:
```bash
# Check web interfaces (use your existing dns1 credentials)
# http://192.168.20.29:5380
# http://192.168.20.28:5380

# Test DNS resolution
dig @192.168.20.29 pve1.lab.klsll.com
dig @192.168.20.28 pve1.lab.klsll.com

# Check DHCP configuration (should be present but disabled)
# Log into web UI → DHCP → Verify scopes exist
```

---

## Step 4: Configure DNS Zone Replication (5 minutes)

### In Technitium Web UI:

**On technitium-dns1 (192.168.20.29):**
1. Log in to http://192.168.20.29:5380
2. Go to **Zones**
3. For each zone, click **Settings**
4. Under **Zone Transfer**:
   - Enable: "Allow zone transfer"
   - Add: 192.168.20.28 (technitium-dns2)
5. Click **Save**

**On technitium-dns2 (192.168.20.28):**
1. Log in to http://192.168.20.28:5380
2. Go to **Zones**
3. Click **Add Zone** → **Secondary Zone**
4. Primary server: 192.168.20.29
5. Select zones to replicate
6. Click **Add**

---

## Step 5: Set Up Daily Automated Backups (5 minutes)

### Test backup first:
```bash
cd /mnt/d/cluster/monger-homelab

# Run manual backup
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml

# Verify backups on Unraid
ls -lh /mnt/unraid-backups/technitium/
```

You should see 4 backup files:
- `dns1-YYYY-MM-DD-HHMM.tar.gz`
- `dns2-YYYY-MM-DD-HHMM.tar.gz`
- `technitium-dns1-YYYY-MM-DD-HHMM.tar.gz`
- `technitium-dns2-YYYY-MM-DD-HHMM.tar.gz`

### Set up cron job:
```bash
# Edit crontab
crontab -e

# Add this line (runs daily at 2:00 AM)
0 2 * * * cd /mnt/d/cluster/monger-homelab && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml >> /tmp/dns-backup.log 2>&1
```

### Verify cron job:
```bash
# List cron jobs
crontab -l

# Check log after first run
tail -f /tmp/dns-backup.log
```

---

## Step 6: Update DHCP to Add New DNS as Secondary (Week 1)

### On legacy dns1 (192.168.20.3):

**VLAN 20 (Homelab):**
1. Log into http://192.168.20.3:5380
2. Go to **DHCP** → **Scopes** → **192.168.20.0/24**
3. Edit **DNS Servers**:
   - Primary: 192.168.20.3 (keep current)
   - Secondary: 192.168.20.29 (add new dns1)
   - Tertiary: 192.168.20.28 (add new dns2)
4. Save and wait for DHCP leases to renew

**VLAN 30 (IoT):**
1. Go to **DHCP** → **Scopes** → **192.168.30.0/24**
2. Edit **DNS Servers**:
   - Primary: 192.168.20.3 (keep current)
   - Secondary: 192.168.30.29 (add new dns1 VLAN 30 IP)
   - Tertiary: 192.168.30.28 (add new dns2 VLAN 30 IP)
3. Save

### Monitor DNS queries:
```bash
# Check logs on new servers
ssh james@192.168.20.29 "docker logs -f technitium"
ssh james@192.168.20.28 "docker logs -f technitium"

# Should see queries coming in as clients renew DHCP
```

---

## Step 7: Configure DHCP on New Servers (Week 2)

**⚠️ DO NOT ENABLE YET - Just configure!**

### On technitium-dns1 (192.168.20.29):

**VLAN 20 Scope:**
1. Log into http://192.168.20.29:5380
2. Go to **DHCP** → **Create Scope**
3. Configure:
   - Network: 192.168.20.0/24
   - Start: 192.168.20.50
   - End: 192.168.20.250
   - Lease: 24 hours
   - Gateway: 192.168.20.1
   - DNS: 192.168.20.29, 192.168.20.28
   - Domain: lab.klsll.com
4. Add reservations for infrastructure
5. **Enable Failover**:
   - Peer: 192.168.20.28
   - Shared secret: (generate strong password)
6. **DO NOT ENABLE SCOPE**

**VLAN 30 Scope:**
1. Create another scope:
   - Network: 192.168.30.0/24
   - Start: 192.168.30.50
   - End: 192.168.30.250
   - Lease: 24 hours
   - Gateway: 192.168.30.1
   - DNS: 192.168.30.29, 192.168.30.28
   - Domain: iot.klsll.com
2. Add reservations
3. **Enable Failover** (same peer and secret)
4. **DO NOT ENABLE SCOPE**

### Repeat on technitium-dns2 (192.168.20.28):
- Create identical scopes
- Configure identical reservations
- Enable failover with same shared secret
- **DO NOT ENABLE SCOPES**

---

## Step 8: DHCP Cutover (Week 3 - Maintenance Window)

### Pre-cutover checklist:
- [ ] DNS working on new servers for 1+ week
- [ ] Zone replication working
- [ ] DHCP scopes configured on both new servers
- [ ] Failover configured and tested
- [ ] Backups running daily
- [ ] Rollback plan documented
- [ ] Maintenance window scheduled

### Cutover procedure:
```bash
# 1. Disable DHCP on legacy dns1
# Log into http://192.168.20.3:5380
# DHCP → Scopes → Disable both scopes

# 2. Enable DHCP on new servers
# Log into http://192.168.20.29:5380
# DHCP → Scopes → Enable both scopes
# Log into http://192.168.20.28:5380
# DHCP → Scopes → Enable both scopes

# 3. Force renewal on test client
sudo dhclient -r && sudo dhclient

# 4. Verify new DHCP lease
ip addr show
cat /etc/resolv.conf

# 5. Monitor DHCP leases on new servers
# Web UI → DHCP → Leases
```

---

## Verification Checklist

### DNS Verification:
```bash
# Test from VLAN 20
dig @192.168.20.29 google.com
dig @192.168.20.28 google.com
dig @192.168.20.29 pve1.lab.klsll.com

# Test from VLAN 30
dig @192.168.30.29 google.com
dig @192.168.30.28 google.com
```

### DHCP Verification:
```bash
# Check lease count on new servers
# Web UI → DHCP → Leases → Should see active leases

# Test failover
ssh james@192.168.20.29 "docker stop technitium"
# Wait 30 seconds, test DHCP renewal
sudo dhclient -r && sudo dhclient
# Should still get IP from dns2
ssh james@192.168.20.29 "docker start technitium"
```

### Backup Verification:
```bash
# Check daily backups
ls -lht /mnt/unraid-backups/technitium/ | head -10

# Verify backup size (should be consistent)
du -sh /mnt/unraid-backups/technitium/*

# Check cron log
tail -20 /tmp/dns-backup.log
```

---

## Troubleshooting

### VLAN 30 not working:
```bash
# Check Proxmox VM network config
ssh james@192.168.20.100 "qm config 105"
ssh james@192.168.20.101 "qm config 106"

# Check interface on VM
ssh james@192.168.20.29 "ip addr show"
ssh james@192.168.20.29 "ip route"

# Test VLAN 30 gateway
ssh james@192.168.20.29 "ping -c 3 192.168.30.1"
```

### Backups failing:
```bash
# Check Unraid mount
df -h | grep unraid
mount | grep unraid

# Remount if needed
sudo umount /mnt/unraid-backups
sudo mount -a

# Test connectivity
ansible -i inventory/raclette/inventory.ini dns_old,technitium_dns -m ping
```

### DHCP conflicts:
```bash
# Ensure only one DHCP server active per VLAN
# Check legacy dns1
ssh james@192.168.20.3 "docker logs technitium | grep DHCP"

# Check new servers
ssh james@192.168.20.29 "docker logs technitium | grep DHCP"
```

---

## Quick Reference

### Important IPs:
- **Unraid**: 192.168.20.5 (unraid.klsll.com)
- **Legacy dns1**: 192.168.20.3 (dns1.lab.klsll.com)
- **Legacy dns2**: 192.168.20.2 (dns2.lab.klsll.com)
- **New dns1 (VLAN 20)**: 192.168.20.29
- **New dns1 (VLAN 30)**: 192.168.30.29
- **New dns2 (VLAN 20)**: 192.168.20.28
- **New dns2 (VLAN 30)**: 192.168.30.28

### Key Commands:
```bash
# Test backup
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml

# Configure VLAN 30
ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_vlan30.yml

# Backup and restore
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml

# Check backups
ls -lh /mnt/unraid-backups/technitium/
```

---

## Next Steps After Setup

1. ✅ Monitor DNS queries for 1 week
2. ✅ Verify backups running daily
3. ✅ Test zone replication
4. ✅ Plan DHCP cutover maintenance window
5. ✅ Follow `DNS_MIGRATION_PLAN.md` for complete migration

---

Last Updated: 2025-01-16
