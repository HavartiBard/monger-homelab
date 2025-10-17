# DNS + DHCP Migration Plan
## From dns1 (VM 100) to Technitium Cluster

## Overview
Migrate DNS and DHCP services from single server (dns1/VM 100) to redundant Technitium cluster with failover.

---

## Current State
- **dns1.lab.klsll.com**: 192.168.20.3 (VM 100) on pve1
  - Primary DNS server
  - DHCP server for VLAN 20 (192.168.20.0/24 - Homelab)
  - DHCP server for VLAN 30 (192.168.30.0/24 - IoT)
- **dns2.lab.klsll.com**: 192.168.20.2 (VM ?) on pve2
  - Secondary DNS server
  - Current role unclear - to be documented

## Target State
- **technitium-dns1 (VM 105)**: 192.168.20.29 on pve1
  - Primary DNS + DHCP with failover
- **technitium-dns2 (VM 106)**: 192.168.20.28 on pve2
  - Secondary DNS + DHCP with failover
- **Redundancy**: Either server can handle full load

---

## Migration Timeline (4 weeks)

### Week 1: DNS Configuration & Testing

#### Day 1-2: Initial Setup
- [ ] Change admin passwords on both new servers
  - http://192.168.20.29:5380
  - http://192.168.20.28:5380
- [ ] Document current DNS zones from old dns1
- [ ] Document current DHCP configuration from old dns1

#### Day 3-4: DNS Configuration
**On technitium-dns1 (192.168.20.29):**
- [ ] Configure forwarders (upstream DNS)
- [ ] Create local zones (if any)
- [ ] Import/recreate custom DNS records
- [ ] Test resolution: `dig @192.168.20.29 google.com`

**On technitium-dns2 (192.168.20.28):**
- [ ] Configure identical forwarders
- [ ] Set up zone replication from dns1
- [ ] Test resolution: `dig @192.168.20.28 google.com`

#### Day 5-7: Add as Secondary DNS
- [ ] Update DHCP on old dns1 to advertise:
  - Primary: 192.168.20.100 (old)
  - Secondary: 192.168.20.29 (new dns1)
  - Tertiary: 192.168.20.28 (new dns2)
- [ ] Force DHCP renewal on test clients
- [ ] Monitor DNS query logs on new servers
- [ ] Verify no errors/issues

---

### Week 2: DHCP Configuration (No Cutover Yet)

#### Day 8-10: DHCP Setup on New Servers
**On technitium-dns1 (192.168.20.29):**
- [ ] Navigate to DHCP section in web UI

**VLAN 20 Scope (Homelab):**
- [ ] Create DHCP scope:
  - Network: 192.168.20.0/24
  - Start IP: 192.168.20.50
  - End IP: 192.168.20.250
  - Lease time: 24 hours
  - Gateway: 192.168.20.1
  - DNS servers: 192.168.20.29, 192.168.20.28
  - Domain name: lab.klsll.com
  
**VLAN 30 Scope (IoT):**
- [ ] Create DHCP scope:
  - Network: 192.168.30.0/24
  - Start IP: 192.168.30.50
  - End IP: 192.168.30.250
  - Lease time: 24 hours
  - Gateway: 192.168.30.1
  - DNS servers: 192.168.20.29, 192.168.20.28
  - Domain name: iot.klsll.com

- [ ] Configure DHCP reservations for critical hosts:
  - Proxmox nodes (pve1, pve2)
  - Network equipment
  - DNS servers (dns1, dns2, technitium-dns1, technitium-dns2)
  - Unraid NAS
  - Other infrastructure
  
- [ ] **Enable DHCP Failover** for BOTH scopes:
  - Peer: 192.168.20.28
  - Shared secret: (generate strong password)
- [ ] **DO NOT ENABLE DHCP YET**

**On technitium-dns2 (192.168.20.28):**
- [ ] Create identical DHCP scopes (VLAN 20 + VLAN 30)
- [ ] Configure identical DHCP reservations
- [ ] **Enable DHCP Failover** for BOTH scopes:
  - Peer: 192.168.20.29
  - Same shared secret as dns1
- [ ] **DO NOT ENABLE DHCP YET**

#### Day 11-14: Pre-Cutover Validation
- [ ] Verify DNS is working well on new servers
- [ ] Review DHCP configuration (double-check everything)
- [ ] Document rollback procedure
- [ ] Schedule maintenance window for DHCP cutover

---

### Week 3: DHCP Cutover

#### Maintenance Window (Evening/Weekend)
**Preparation:**
- [ ] Announce maintenance window to users
- [ ] Have console access to Proxmox ready
- [ ] Backup old dns1 configuration

**Cutover Steps (30-60 minutes):**

1. **Disable DHCP on old dns1 (VM 100)**
   - Log into old dns1 web interface
   - Stop DHCP service
   - Verify DHCP is stopped

2. **Enable DHCP on new servers**
   - On technitium-dns1: Enable DHCP scope
   - On technitium-dns2: Enable DHCP scope
   - Verify failover status shows "Connected"

3. **Test DHCP on a client**
   ```bash
   # Release and renew
   sudo dhclient -r && sudo dhclient
   # Or on Windows
   ipconfig /release && ipconfig /renew
   ```
   - Verify client gets IP in correct range
   - Verify DNS servers are 192.168.20.29, 192.168.20.28
   - Verify gateway is correct

4. **Force renewal on critical infrastructure**
   - Proxmox nodes (if using DHCP)
   - Network equipment
   - Test VMs

5. **Monitor DHCP leases**
   - Check lease count on both new servers
   - Verify failover is working (leases distributed)
   - Watch for any errors in logs

**Post-Cutover (24-48 hours):**
- [ ] Monitor DHCP lease assignments
- [ ] Check for any clients with issues
- [ ] Verify failover is working (test by stopping one server)
- [ ] Document any issues and resolutions

---

### Week 4: Stabilization & Cleanup

#### Day 22-25: Flip DNS Priority
- [ ] Update DHCP to advertise:
  - Primary DNS: 192.168.20.29 (new dns1)
  - Secondary DNS: 192.168.20.28 (new dns2)
  - Tertiary DNS: 192.168.20.100 (old dns1 - backup only)
- [ ] Monitor DNS query distribution
- [ ] Verify old dns1 is only getting backup queries

#### Day 26-28: Final Monitoring
- [ ] Verify no issues with new DNS/DHCP
- [ ] Check failover works (test by rebooting one server)
- [ ] Document final configuration

#### Day 29-30: Decommission Old DNS
- [ ] Remove old dns1 from DHCP DNS list
- [ ] Update DHCP to only advertise new servers
- [ ] Shut down old dns1 (VM 100) - **don't delete yet**
- [ ] Monitor for 48 hours

#### After 1 Week of Stability:
- [ ] Delete VM 100 (old dns1)
- [ ] Delete VM 102 (old pihole2) if still present
- [ ] Delete VM 103 (old technitiumdns) if still present
- [ ] Update documentation

---

## Rollback Procedures

### If Issues During DHCP Cutover:
1. **Immediately re-enable DHCP on old dns1 (VM 100)**
2. Disable DHCP on new servers
3. Force DHCP renewal on affected clients
4. Investigate issues before attempting again

### If Issues After Cutover:
1. Re-enable DHCP on old dns1
2. Update DHCP to point back to old DNS
3. Disable DHCP on new servers
4. Force renewal on all clients
5. Keep new servers running for investigation

---

## Testing Checklist

### DNS Testing:
```bash
# Test external resolution
dig @192.168.20.29 google.com
dig @192.168.20.28 google.com

# Test local zones (if any)
dig @192.168.20.29 <your-local-domain>
dig @192.168.20.28 <your-local-domain>

# Test reverse DNS (if configured)
dig @192.168.20.29 -x 192.168.20.29
```

### DHCP Testing:
```bash
# On Linux client
sudo dhclient -r && sudo dhclient
ip addr show
cat /etc/resolv.conf

# On Windows client
ipconfig /release
ipconfig /renew
ipconfig /all
```

### Failover Testing:
```bash
# Stop one server and verify DHCP still works
ssh james@192.168.20.29 "sudo docker stop technitium"
# Test DHCP renewal on client
# Restart server
ssh james@192.168.20.29 "sudo docker start technitium"
```

---

## Important Notes

### DHCP Scope Planning:

**VLAN 20 (Homelab - 192.168.20.0/24):**
- Reserved: 192.168.20.1-49 (infrastructure, static IPs)
- DHCP pool: 192.168.20.50-250
- Reserved: 192.168.20.251-254 (future use)

**VLAN 30 (IoT - 192.168.30.0/24):**
- Reserved: 192.168.30.1-49 (infrastructure, static IPs)
- DHCP pool: 192.168.30.50-250
- Reserved: 192.168.30.251-254 (future use)

### DHCP Reservations to Configure:
- Proxmox nodes (pve1, pve2)
- Network switches/routers
- NAS/storage devices
- Printers
- IoT devices that need consistent IPs
- Infrastructure VMs (K3s nodes, etc.)

### Monitoring:
- Watch DHCP lease count on both servers
- Monitor DNS query logs for errors
- Check failover status regularly
- Set up alerts if possible

### Security:
- Change default admin passwords ⚠️
- Use strong DHCP failover shared secret
- Consider restricting web UI access to management network
- Enable HTTPS for web UI (self-signed cert is fine)

---

## Success Criteria

✅ Both DNS servers responding to queries
✅ Both DHCP servers issuing leases
✅ Failover working (can lose one server without impact)
✅ All clients getting correct IP/DNS configuration
✅ No DNS resolution errors
✅ Old dns1 can be safely shut down

---

## Contact & Support

- **Technitium Documentation**: https://technitium.com/dns/
- **DHCP Failover Guide**: https://technitium.com/dns/help.html#dhcp-failover
- **Community Forum**: https://forum.technitium.com/

---

## Change Log

| Date | Change | Status |
|------|--------|--------|
| 2025-01-16 | Initial plan created | Pending |
| | DNS servers deployed | ✅ Complete |
| | Ansible configuration complete | ✅ Complete |
| | DNS configuration | 🔄 In Progress |
| | DHCP cutover | ⏳ Pending |
| | Old server decommission | ⏳ Pending |
