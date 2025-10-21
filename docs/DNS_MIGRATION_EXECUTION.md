# DNS Migration Execution Plan

## Executive Summary

Migrate DNS and DHCP services from old servers to Terraform-managed Technitium cluster **BEFORE** deploying K3s.

**Why now?** K3s nodes need stable DNS during deployment. Complete this migration first.

---

## Current State (From Resource Check)

### Running Servers

| Server | Type | Location | IP | Status | Role |
|--------|------|----------|----| -------|------|
| **technitium-dns1** | VM 105 | pve1 | 192.168.20.29 | ✅ Running | NEW (needs config) |
| **technitium-dns2** | VM 106 | pve2 | 192.168.20.28 | ✅ Running | NEW (needs config) |
| **dns1** | LXC 100 | pve2 | 192.168.20.? | ✅ Running | OLD (to decommission) |
| **technitiumdns** | LXC 103 | pve1 | 192.168.20.? | ✅ Running | OLD (to decommission) |

### Configuration Status

- ✅ New VMs deployed via Terraform
- ✅ DNS zones defined (`config/dns_zones.yml`)
- ✅ DHCP scopes defined (`config/dhcp_scopes.yml`)
- ⚠️ DHCP disabled on new servers (safe)
- ❌ DNS/DHCP not yet deployed to new servers
- ❌ Old servers still active

---

## Migration Strategy (Simplified)

**Timeline: 1-2 days** (was 4 weeks, but we can accelerate)

### Phase 1: Deploy DNS to New Servers (1 hour)
### Phase 2: Test DNS (1 hour)
### Phase 3: Cutover DNS (30 minutes)
### Phase 4: Deploy DHCP Config (1 hour)
### Phase 5: Cutover DHCP (1 hour + monitoring)
### Phase 6: Decommission Old Servers (after 48h stability)

---

## Phase 1: Deploy DNS Configuration to New Servers

### Prerequisites Check

```bash
cd /opt/development/monger-homelab

# Verify new DNS servers are accessible
ansible -i inventory/raclette/inventory.ini dns_servers -m ping

# Check if Technitium is running
ansible -i inventory/raclette/inventory.ini dns_servers -m shell -a "docker ps | grep technitium"
```

### Deploy DNS Zones

```bash
# Deploy DNS zones and forwarders to both new servers
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/configure_dns_zones.yml

# This will:
# - Create forward zones (lab.klsll.com, iot.klsll.com, klsll.com)
# - Create reverse zones (20.168.192.in-addr.arpa, 30.168.192.in-addr.arpa)
# - Add all A, PTR, CNAME records
# - Configure Cloudflare forwarders (1.1.1.1, 1.0.0.1)
# - Enable DNSSEC
```

**Expected Output:**
```
PLAY RECAP ************************************************************
technitium-dns1   : ok=15  changed=12  unreachable=0  failed=0
technitium-dns2   : ok=15  changed=12  unreachable=0  failed=0
```

---

## Phase 2: Test DNS Resolution

### Test from Development Machine

```bash
# Test external DNS resolution
dig @192.168.20.29 google.com +short
dig @192.168.20.28 google.com +short
# Should return Google IPs

# Test internal DNS (lab.klsll.com zone)
dig @192.168.20.29 pve1.lab.klsll.com +short
dig @192.168.20.28 pve1.lab.klsll.com +short
# Should return: 192.168.20.100

# Test reverse DNS
dig @192.168.20.29 -x 192.168.20.100 +short
dig @192.168.20.28 -x 192.168.20.100 +short
# Should return: pve1.lab.klsll.com.

# Test CNAME
dig @192.168.20.29 proxmox.lab.klsll.com +short
# Should return: pve1.lab.klsll.com. then 192.168.20.100

# Test both forwarders work
dig @192.168.20.29 amazon.com +short
dig @192.168.20.28 amazon.com +short
```

### Verify Web Interface

```bash
# Open in browser
http://192.168.20.29:5380
http://192.168.20.28:5380

# Check:
# - Zones are listed (lab.klsll.com, iot.klsll.com, etc.)
# - Records are present
# - Forwarders configured
# - DNSSEC enabled
```

---

## Phase 3: DNS Cutover

### Option A: Direct Cutover (Recommended for Homelab)

**Best for:** Low-risk homelab environment

```bash
# 1. Update your dev machine to use new DNS
sudo vi /etc/resolv.conf
# Change to:
nameserver 192.168.20.29
nameserver 192.168.20.28

# 2. Test immediately
ping pve1.lab.klsll.com
ping google.com

# 3. Update router/DHCP (if not using Technitium DHCP)
# - Log into your router
# - Change DNS servers to 192.168.20.29, 192.168.20.28
# - Force DHCP renewal on all clients
```

### Option B: Gradual Cutover (Lower Risk)

**Best for:** Production-like environment

```bash
# 1. Add new DNS as secondary on old DHCP server
# Edit old dns1 DHCP config:
# Primary: <old-dns-ip>
# Secondary: 192.168.20.29
# Tertiary: 192.168.20.28

# 2. Wait 24 hours, monitor queries

# 3. Flip priority
# Primary: 192.168.20.29
# Secondary: 192.168.20.28
# Tertiary: <old-dns-ip>

# 4. Wait 24 hours

# 5. Remove old DNS entirely
# Primary: 192.168.20.29
# Secondary: 192.168.20.28
```

---

## Phase 4: Deploy DHCP Configuration

### Deploy DHCP Scopes (But Keep Disabled)

```bash
# Deploy DHCP configuration to new servers
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/configure_dhcp_api.yml

# This will:
# - Create DHCP scopes for VLAN 20 (lab) and VLAN 30 (IoT)
# - Add static reservations for infrastructure
# - Configure DHCP failover between servers
# - BUT scopes remain DISABLED (safe)
```

### Verify DHCP Configuration

```bash
# Check web interface
http://192.168.20.29:5380
# Go to DHCP → Scopes

# Verify:
# - Homelab VLAN 20 scope exists (DISABLED)
# - IoT VLAN 30 scope exists (DISABLED)
# - Reservations configured (pve1, pve2, unraid)
# - Failover configured (peer: 192.168.20.28)
```

---

## Phase 5: DHCP Cutover

### Before Starting

**Pre-flight Checklist:**
- [ ] DNS working perfectly on new servers
- [ ] All static reservations configured
- [ ] Failover configured between servers
- [ ] Maintenance window scheduled
- [ ] Backup of old DHCP config taken
- [ ] Console access to Proxmox available

### Cutover Steps (30 minutes)

#### 1. Identify Current DHCP Server

```bash
# Find where DHCP is currently running
# Check old servers:
ssh james@<old-dns1-ip> "systemctl status dhcpd || docker ps | grep dhcp"
ssh james@<old-dns2-ip> "systemctl status dhcpd || docker ps | grep dhcp"

# Or check from a client
# Linux:
cat /var/lib/dhcp/dhclient.leases | grep dhcp-server-identifier
# Windows:
ipconfig /all | findstr "DHCP Server"
```

#### 2. Disable DHCP on Old Server

```bash
# Via web UI or command line
ssh james@<old-dhcp-server> "sudo systemctl stop dhcpd"
# OR if Technitium:
# Web UI → DHCP → Disable scope

# Verify stopped
ssh james@<old-dhcp-server> "sudo systemctl status dhcpd"
```

#### 3. Enable DHCP on New Servers

**Method 1: Via Ansible (Recommended)**

Edit `config/dhcp_scopes.yml`:
```yaml
dhcp_scopes:
  - name: "Homelab VLAN 20"
    enabled: true  # Change from false to true
    # ... rest of config
  
  - name: "IoT VLAN 30"
    enabled: true  # Change from false to true
    # ... rest of config
```

Deploy:
```bash
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/configure_dhcp_api.yml
```

**Method 2: Via Web UI**

```bash
# On both servers:
# http://192.168.20.29:5380
# http://192.168.20.28:5380

# Go to: DHCP → Scopes → Homelab VLAN 20 → Enable
# Go to: DHCP → Scopes → IoT VLAN 30 → Enable

# Verify failover shows "Connected" status
```

#### 4. Test DHCP on a Client

```bash
# On a test Linux client
sudo dhclient -r eth0  # Release
sudo dhclient -v eth0  # Renew with verbose

# Check what you got
ip addr show eth0
cat /etc/resolv.conf

# Verify:
# - IP in correct range (192.168.20.50-250 or 192.168.30.50-250)
# - DNS servers are 192.168.20.29, 192.168.20.28
# - Gateway is correct (192.168.20.1 or 192.168.30.1)
# - Domain is lab.klsll.com or iot.klsll.com

# Test DNS resolution works
ping pve1.lab.klsll.com
ping google.com
```

#### 5. Monitor DHCP Leases

```bash
# Web UI on both servers
http://192.168.20.29:5380 → DHCP → Leases
http://192.168.20.28:5380 → DHCP → Leases

# Check:
# - Leases are being issued
# - Leases distributed across both servers (failover working)
# - No errors in logs
```

#### 6. Force Renewal on Critical Infrastructure

```bash
# On Proxmox nodes (if using DHCP - usually static)
# On test VMs
# On workstations

# Linux:
sudo dhclient -r && sudo dhclient

# Windows:
ipconfig /release && ipconfig /renew

# macOS:
sudo ipconfig set en0 DHCP
```

---

## Phase 6: Verify and Stabilize (48 hours)

### Monitoring Checklist

Day 1:
- [ ] All clients getting DHCP leases
- [ ] DNS resolution working everywhere
- [ ] DHCP failover status "Connected"
- [ ] No errors in logs
- [ ] Static reservations working

Day 2:
- [ ] Check lease renewals
- [ ] Test failover (stop one server temporarily)
- [ ] Verify no complaints from users
- [ ] Monitor logs for issues

### Test DHCP Failover

```bash
# Stop primary server
ssh james@192.168.20.29 "sudo docker stop technitium"

# Test DHCP still works
# On a client:
sudo dhclient -r && sudo dhclient

# Should get lease from secondary (192.168.20.28)

# Bring primary back
ssh james@192.168.20.29 "sudo docker start technitium"

# Verify failover reconnects
# Check web UI: DHCP → Scopes → Failover status should be "Connected"
```

---

## Phase 7: Decommission Old Servers (After 48h Stability)

### Safe Decommission Steps

```bash
# 1. Document old server IPs (for rollback if needed)
echo "Old DNS1 (LXC 100): $(ssh james@pve2 'pct exec 100 -- hostname -I')" >> OLD_DNS_BACKUP.txt
echo "Old DNS2 (LXC 103): $(ssh james@pve1 'pct exec 103 -- hostname -I')" >> OLD_DNS_BACKUP.txt

# 2. Shutdown old servers (don't delete yet)
ssh james@pve2 "pct shutdown 100"
ssh james@pve1 "pct shutdown 103"

# 3. Monitor for 1 week

# 4. After 1 week of stability, delete
ssh james@pve2 "pct destroy 100"
ssh james@pve1 "pct destroy 103"
```

---

## Rollback Procedures

### If DNS Issues

```bash
# Re-enable old DNS server
ssh james@<old-dns-ip> "sudo systemctl start named"  # or equivalent

# Update resolv.conf on affected machines
sudo vi /etc/resolv.conf
# Change back to old DNS IP

# Investigate issue with new servers before retry
```

### If DHCP Issues

```bash
# 1. Immediately disable DHCP on new servers
# Via web UI: Disable scopes

# 2. Re-enable old DHCP server
ssh james@<old-dhcp-ip> "sudo systemctl start dhcpd"

# 3. Force renewal on affected clients
sudo dhclient -r && sudo dhclient

# 4. Investigate before retry
```

---

## Success Criteria

✅ **DNS Working:**
- Both new servers resolving external domains
- Both new servers resolving internal zones (lab.klsll.com, etc.)
- Reverse DNS working
- No resolution errors

✅ **DHCP Working:**
- Clients getting leases from new servers
- Static reservations working
- Failover connected and working
- No duplicate IPs issued

✅ **Stability:**
- 48 hours with no issues
- Failover tested successfully
- All infrastructure using new DNS/DHCP
- Old servers can be safely powered off

---

## Quick Commands Reference

### DNS Testing
```bash
dig @192.168.20.29 google.com +short
dig @192.168.20.29 pve1.lab.klsll.com +short
dig @192.168.20.29 -x 192.168.20.100 +short
```

### DHCP Testing
```bash
sudo dhclient -r && sudo dhclient  # Linux
ipconfig /release && ipconfig /renew  # Windows
```

### Check Services
```bash
ansible -i inventory/raclette/inventory.ini dns_servers -m shell -a "docker ps"
ansible -i inventory/raclette/inventory.ini dns_servers -m shell -a "docker logs technitium --tail 50"
```

### Web Interfaces
- DNS1: http://192.168.20.29:5380
- DNS2: http://192.168.20.28:5380

---

## Timeline Summary

| Phase | Duration | Can Skip K3s? |
|-------|----------|---------------|
| Deploy DNS Config | 1 hour | No |
| Test DNS | 1 hour | No |
| DNS Cutover | 30 min | No |
| Deploy DHCP Config | 1 hour | Yes* |
| DHCP Cutover | 1 hour | Yes* |
| Monitoring | 48 hours | Yes* |

**Note:** You can deploy K3s after DNS is working, even if DHCP migration is pending. K3s VMs will use the new DNS servers.

---

## Next Steps After Migration

1. ✅ DNS migrated and stable
2. ✅ DHCP migrated and stable (or scheduled)
3. 🚀 **Deploy K3s cluster** using distributed HA configuration
4. 🚀 Run bootstrap-cicd.sh
5. 🚀 Deploy monitoring and applications

**Bottom line: DNS must be done before K3s. DHCP can wait if needed, but better to complete it first.**
