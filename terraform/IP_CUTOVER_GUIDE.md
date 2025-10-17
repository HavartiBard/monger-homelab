# DNS IP Cutover Strategy

## Overview
Two-phase approach to take over legacy DNS IPs with zero client disruption.

---

## Phase 1: Deploy with Temporary IPs (Week 1-2) ✅ **CURRENT**

### IP Assignments:
| Server | VLAN 20 (Homelab) | VLAN 30 (IoT) | Status |
|--------|-------------------|---------------|--------|
| technitium-dns1 | 192.168.20.29 (DHCP) | 192.168.30.29 (Static) | Testing |
| technitium-dns2 | 192.168.20.28 (DHCP) | 192.168.30.28 (Static) | Testing |
| dns1 (legacy) | 192.168.20.3 | N/A | Production |
| dns2 (legacy) | 192.168.20.2 | N/A | Production |

### Deploy Now:
```bash
cd /mnt/d/cluster/monger-homelab/terraform

# Deploy with temporary IPs (dns_use_legacy_ips = false)
terraform apply -var-file="dns.tfvars" -target=proxmox_vm_qemu.dns -parallelism=1
```

### Configuration & Testing (Week 1-2):
1. ✅ Install Technitium DNS
2. ✅ Restore legacy DNS configuration
3. ✅ Configure DNS zones and replication
4. ✅ Test DNS resolution on both VLANs
5. ✅ Add as secondary DNS in DHCP for testing
6. ✅ Configure DHCP scopes (don't enable)
7. ✅ Monitor for 1-2 weeks

---

## Phase 2: Cutover to Legacy IPs (Week 3) 🎯 **FUTURE**

### Target IP Assignments:
| Server | VLAN 20 (Homelab) | VLAN 30 (IoT) | Status |
|--------|-------------------|---------------|--------|
| technitium-dns1 | 192.168.20.3 (Static) | 192.168.30.3 (Static) | Production |
| technitium-dns2 | 192.168.20.2 (Static) | 192.168.30.2 (Static) | Production |
| dns1 (legacy) | OFFLINE | OFFLINE | Decommissioned |
| dns2 (legacy) | OFFLINE | OFFLINE | Decommissioned |

### Why This Works:
- ✅ **Zero client changes**: Clients keep using 192.168.20.2/3
- ✅ **No DHCP updates**: DNS IPs stay the same
- ✅ **No DNS propagation**: Static configs unchanged
- ✅ **Instant cutover**: Just swap the servers
- ✅ **Easy rollback**: Bring old servers back if needed

---

## Cutover Procedure (Maintenance Window)

### Pre-Cutover Checklist:
- [ ] New DNS servers tested for 1-2 weeks
- [ ] DNS resolution working on both VLANs
- [ ] Zone replication configured
- [ ] DHCP scopes configured (but disabled)
- [ ] Backups of both old and new servers
- [ ] Maintenance window scheduled (30-60 minutes)
- [ ] Rollback plan documented

### Step 1: Backup Everything
```bash
cd /mnt/d/cluster/monger-homelab

# Backup all DNS servers
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml

# Verify backups
ls -lh /mnt/unraid-backups/technitium/
```

### Step 2: Shutdown Legacy DNS Servers
```bash
# Gracefully shutdown legacy servers
ssh james@192.168.20.3 "sudo shutdown -h now"
ssh james@192.168.20.2 "sudo shutdown -h now"

# Wait 30 seconds for shutdown
sleep 30

# Verify they're offline
ping -c 3 192.168.20.3  # Should fail
ping -c 3 192.168.20.2  # Should fail
```

### Step 3: Enable Legacy IPs in Terraform
```bash
cd /mnt/d/cluster/monger-homelab/terraform

# Apply with legacy IPs enabled
terraform apply -var-file="dns.tfvars" -var="dns_use_legacy_ips=true" -target=proxmox_vm_qemu.dns
```

This will:
- Change technitium-dns1 to 192.168.20.3 (VLAN 20) and 192.168.30.3 (VLAN 30)
- Change technitium-dns2 to 192.168.20.2 (VLAN 20) and 192.168.30.2 (VLAN 30)

### Step 4: Verify Cutover
```bash
# Test DNS resolution on new IPs
dig @192.168.20.3 google.com
dig @192.168.20.2 google.com
dig @192.168.30.3 google.com
dig @192.168.30.2 google.com

# Test from client
dig google.com  # Should use new servers automatically

# Check web interfaces
# http://192.168.20.3:5380
# http://192.168.20.2:5380
```

### Step 5: Update Ansible Inventory
```bash
# Edit inventory/raclette/inventory.ini
```

Change:
```ini
[technitium_dns]
technitium-dns1 ansible_host=192.168.20.29 ansible_user=james
technitium-dns2 ansible_host=192.168.20.28 ansible_user=james
```

To:
```ini
[technitium_dns]
technitium-dns1 ansible_host=192.168.20.3 ansible_user=james
technitium-dns2 ansible_host=192.168.20.2 ansible_user=james
```

### Step 6: Enable DHCP (Optional)
If you're ready to migrate DHCP as well:
```bash
# Log into web UI
# http://192.168.20.3:5380

# Enable DHCP scopes for both VLANs
# Monitor DHCP leases
```

### Step 7: Monitor (24-48 hours)
- Check DNS query logs
- Verify DHCP leases (if enabled)
- Monitor for any client issues
- Keep legacy servers powered off but don't delete

---

## Rollback Plan

If issues occur during cutover:

### Quick Rollback:
```bash
# 1. Disable legacy IPs in Terraform
cd /mnt/d/cluster/monger-homelab/terraform
terraform apply -var-file="dns.tfvars" -var="dns_use_legacy_ips=false" -target=proxmox_vm_qemu.dns

# 2. Start legacy servers
ssh james@192.168.20.100 "qm start 100"  # dns1
ssh james@192.168.20.101 "qm start XXX"  # dns2 (replace XXX with VM ID)

# 3. Wait for legacy servers to boot
sleep 60

# 4. Verify legacy servers are working
dig @192.168.20.3 google.com
dig @192.168.20.2 google.com
```

---

## Post-Cutover (Week 4+)

### After 1 Week of Stability:
- [ ] Remove legacy DNS from DHCP (if added as tertiary)
- [ ] Update documentation with new IPs
- [ ] Verify backups are working
- [ ] Test failover (stop one server)

### After 2 Weeks of Stability:
- [ ] Decommission legacy VMs
- [ ] Delete old VM backups
- [ ] Update network diagrams
- [ ] Celebrate! 🎉

---

## Network Diagram

### Before Cutover:
```
Clients → 192.168.20.3 (dns1 - legacy) → Internet
       ↘ 192.168.20.2 (dns2 - legacy)

Testing:
       → 192.168.20.29 (technitium-dns1 - new)
       → 192.168.20.28 (technitium-dns2 - new)
```

### After Cutover:
```
Clients → 192.168.20.3 (technitium-dns1) → Internet
       ↘ 192.168.20.2 (technitium-dns2)

Offline:
       X dns1 (legacy - decommissioned)
       X dns2 (legacy - decommissioned)
```

---

## Important Notes

### DHCP Reservations:
After cutover, ensure DHCP reservations are updated:
- Old: Reserve 192.168.20.2/3 for legacy VMs
- New: Reserve 192.168.20.2/3 for new VMs

### DNS Records:
Update any DNS records pointing to old servers:
- dns1.lab.klsll.com → 192.168.20.3 (no change needed)
- dns2.lab.klsll.com → 192.168.20.2 (no change needed)

### Monitoring:
Set up monitoring for new servers:
- DNS query response time
- DHCP lease count
- Container health
- Disk space

---

## Timeline Summary

| Week | Phase | Action |
|------|-------|--------|
| 1-2 | Testing | Deploy with temp IPs, configure, test |
| 3 | Cutover | Shutdown old, enable legacy IPs |
| 4+ | Stabilize | Monitor, decommission old VMs |

---

## Quick Reference

### Current Configuration (Phase 1):
```bash
# Deploy with temp IPs
terraform apply -var-file="dns.tfvars" -target=proxmox_vm_qemu.dns
```

### Future Cutover (Phase 2):
```bash
# Shutdown legacy servers first!
# Then apply with legacy IPs
terraform apply -var-file="dns.tfvars" -var="dns_use_legacy_ips=true" -target=proxmox_vm_qemu.dns
```

### Rollback:
```bash
# Revert to temp IPs
terraform apply -var-file="dns.tfvars" -var="dns_use_legacy_ips=false" -target=proxmox_vm_qemu.dns

# Start legacy servers
qm start 100  # dns1
```

---

**Current Status**: Phase 1 (Testing with temporary IPs)
**Next Step**: Deploy VMs and begin testing
