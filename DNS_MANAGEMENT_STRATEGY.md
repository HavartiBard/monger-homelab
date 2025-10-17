# DNS Management Strategy

## Overview
This document describes how DNS is managed in the homelab, separating static infrastructure (IaC) from dynamic DHCP-assigned records.

---

## Two-Tier DNS Architecture

### **Tier 1: Static Infrastructure (IaC Managed)**
**Managed by:** `config/dns_zones.yml` + `playbook/configure_dns_zones.yml`

**Purpose:** Core infrastructure that rarely changes
- Hypervisors (pve1, pve2)
- Storage servers (unraid)
- DNS servers themselves
- Service aliases (CNAME records)
- Reverse DNS for static IPs

**Characteristics:**
- Version controlled in Git
- Deployed via Ansible API calls
- Tagged with "Managed by Ansible" comment
- High TTL (3600s)

**Example:**
```yaml
- name: "pve1"
  type: "A"
  ttl: 3600
  value: "192.168.20.100"
```

### **Tier 2: Dynamic Records (DHCP Managed)**
**Managed by:** Technitium DHCP dynamic DNS updates

**Purpose:** Devices that get DHCP leases
- Workstations
- Laptops
- Mobile devices
- Temporary VMs

**Characteristics:**
- Auto-created by Technitium when DHCP lease issued
- Auto-deleted when lease expires
- Low TTL (matches lease time)
- NOT in `dns_zones.yml`

**Example:**
- `laptop-james.lab.klsll.com` → 192.168.20.150 (DHCP lease)

---

## How They Coexist

### **Playbook Behavior:**
1. ✅ **Check existing zones** - Don't recreate DHCP-managed zones
2. ✅ **Overwrite only exact matches** - `pve1.lab.klsll.com` (A) won't touch `pve1.lab.klsll.com` (AAAA)
3. ✅ **Tag managed records** - "Managed by Ansible" comment
4. ✅ **Preserve dynamic records** - Only updates records explicitly in YAML

### **DHCP Configuration:**
In Technitium DHCP scope settings:
- **DNS Updates:** Enabled
- **DNS TTL:** 900 (15 minutes)
- **Update Reverse:** Yes
- **Zone:** `lab.klsll.com` or `iot.klsll.com`

---

## Workflow Examples

### **Adding a New Static Server:**
1. Edit `config/dns_zones.yml`:
   ```yaml
   - name: "k8s-master1"
     type: "A"
     ttl: 3600
     value: "192.168.20.110"
   ```

2. Add DHCP reservation in `config/dhcp_scopes.yml`:
   ```yaml
   - hostname: "k8s-master1"
     mac_address: "XX:XX:XX:XX:XX:XX"
     ip_address: "192.168.20.110"
   ```

3. Deploy:
   ```bash
   ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_dhcp_api.yml
   ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_dns_zones.yml
   ```

### **DHCP Client Gets Lease:**
1. Client requests DHCP
2. Technitium assigns IP from pool
3. Technitium auto-creates DNS record: `laptop-james.lab.klsll.com`
4. Record expires when lease expires
5. **Your playbook never touches this record**

### **Updating a Static Record:**
1. Edit `config/dns_zones.yml`
2. Re-run playbook
3. Ansible overwrites only that specific record
4. All other records (static and dynamic) remain unchanged

---

## Best Practices

### **DO:**
- ✅ Put infrastructure servers in `dns_zones.yml`
- ✅ Use DHCP reservations + static DNS for servers
- ✅ Let DHCP handle dynamic client records
- ✅ Use high TTL (3600s) for static records
- ✅ Use descriptive names (`pve1`, not `server1`)

### **DON'T:**
- ❌ Put DHCP client hostnames in `dns_zones.yml`
- ❌ Manually create records that DHCP will manage
- ❌ Use low TTL for infrastructure
- ❌ Delete zones that contain DHCP records

---

## Disaster Recovery

### **Rebuilding from Scratch:**
1. Deploy VMs via Terraform
2. Run Ansible to install Technitium
3. Run `configure_dhcp_api.yml` (DHCP scopes + reservations)
4. Run `configure_dns_zones.yml` (Static DNS records)
5. DHCP clients will auto-register as they renew leases

### **Backup Strategy:**
- **IaC (Git):** `dns_zones.yml`, `dhcp_scopes.yml` (version controlled)
- **Technitium Backup:** Full config backup (includes dynamic records, settings, logs)
- **Restore:** Deploy IaC first, then restore Technitium backup for dynamic state

---

## Future Enhancements

1. **Terraform Integration:**
   - Auto-generate DNS records when VMs are created
   - Update `dns_zones.yml` via Terraform `local_file` resource

2. **Git Hooks:**
   - Validate DNS record syntax before commit
   - Check for duplicate IPs/names

3. **Monitoring:**
   - Alert on DNS resolution failures
   - Track DHCP lease utilization

4. **Split-Horizon DNS:**
   - Different answers for internal vs external queries
   - Public zone for external services

---

## Summary

| Aspect | Static (IaC) | Dynamic (DHCP) |
|--------|-------------|----------------|
| **Managed By** | Ansible + Git | Technitium DHCP |
| **Examples** | pve1, unraid, dns1 | laptop-james, phone-jane |
| **TTL** | 3600s (1 hour) | 900s (15 min) |
| **Lifecycle** | Manual updates | Auto-create/delete |
| **Version Control** | Yes (Git) | No (ephemeral) |
| **Backup** | Git repository | Technitium backup |

**Key Principle:** Infrastructure is code, clients are dynamic state. Keep them separate! 🎯
