# DNS Migration Quick Start

## TL;DR - Execute DNS Migration Before K3s Deployment

**Why:** K3s nodes need stable DNS during deployment. Complete DNS migration first.

**Time:** 2-3 hours total

---

## Current State

✅ **New DNS VMs deployed** (technitium-dns1, technitium-dns2)  
✅ **Configuration files ready** (dns_zones.yml, dhcp_scopes.yml)  
❌ **DNS not configured** on new servers  
❌ **DHCP not configured** on new servers  
🔄 **Old servers still active** (dns1, technitiumdns LXCs)

---

## Quick Execution Plan

### Step 1: Deploy DNS Configuration (30 minutes)

```bash
cd /opt/development/monger-homelab

# Test connectivity
ansible -i inventory/raclette/inventory.ini dns_servers -m ping

# Deploy DNS zones to both new servers
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/configure_dns_zones.yml
```

**What this does:**
- Creates forward zones (lab.klsll.com, iot.klsll.com, klsll.com)
- Creates reverse zones (for PTR records)
- Adds all A, CNAME, and PTR records
- Configures Cloudflare forwarders (1.1.1.1, 1.0.0.1)
- Enables DNSSEC

### Step 2: Test DNS (15 minutes)

```bash
# Test external resolution
dig @192.168.20.29 google.com +short
dig @192.168.20.28 google.com +short

# Test internal zones
dig @192.168.20.29 pve1.lab.klsll.com +short
# Should return: 192.168.20.100

# Test reverse DNS
dig @192.168.20.29 -x 192.168.20.100 +short
# Should return: pve1.lab.klsll.com.

# Check web interfaces
# http://192.168.20.29:5380
# http://192.168.20.28:5380
```

### Step 3: DNS Cutover (15 minutes)

**Update your dev machine:**
```bash
# Edit resolv.conf
sudo vi /etc/resolv.conf

# Change to:
nameserver 192.168.20.29
nameserver 192.168.20.28
```

**Test immediately:**
```bash
ping pve1.lab.klsll.com
ping google.com
nslookup pve1.lab.klsll.com
```

**Update network-wide (optional):**
- Log into your router/firewall
- Change DHCP DNS servers to: 192.168.20.29, 192.168.20.28
- Force DHCP renewal on clients

### Step 4: Deploy DHCP Config (Optional - 30 minutes)

```bash
# Deploy DHCP scopes (stays DISABLED for safety)
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/configure_dhcp_api.yml

# Verify in web UI (DHCP → Scopes)
# - Homelab VLAN 20: DISABLED
# - IoT VLAN 30: DISABLED
# - Failover configured
```

### Step 5: DHCP Cutover (Optional - can do later)

**Only do this if ready to migrate DHCP:**

1. **Disable old DHCP server**
2. **Enable new DHCP** (edit dhcp_scopes.yml, set `enabled: true`)
3. **Redeploy:** `ansible-playbook ... configure_dhcp_api.yml`
4. **Test on a client:** `sudo dhclient -r && sudo dhclient`
5. **Monitor for 48 hours**

---

## Minimum Required for K3s

**✅ Must Complete:**
- Step 1: Deploy DNS Configuration
- Step 2: Test DNS
- Step 3: DNS Cutover (at least on your dev machine)

**⏭️ Can Skip (for now):**
- Step 4: DHCP Configuration
- Step 5: DHCP Cutover

**Why:** K3s VMs need working DNS for name resolution. DHCP can wait if you're using static IPs or existing DHCP.

---

## After DNS is Working

```bash
# You can proceed with K3s deployment
cd /opt/development/monger-homelab/terraform
terraform apply -var-file=k3s-distributed-ha.auto.tfvars

# Then deploy Unraid components per docs/K3S_DISTRIBUTED_HA_SETUP.md
```

---

## Troubleshooting

### DNS not resolving?

```bash
# Check Technitium is running
ansible -i inventory/raclette/inventory.ini dns_servers \
  -m shell -a "docker ps | grep technitium"

# Check logs
ansible -i inventory/raclette/inventory.ini dns_servers \
  -m shell -a "docker logs technitium --tail 50"
```

### Ansible can't reach new DNS servers?

```bash
# Check SSH connectivity
ssh automation@192.168.20.29
ssh automation@192.168.20.28

# Check IPs are correct
ping 192.168.20.29
ping 192.168.20.28
```

### API token error?

The playbooks need API tokens. Check:
```bash
# Verify vault.yml has technitium tokens
cat inventory/raclette/group_vars/vault.yml | grep technitium
```

---

## Files Reference

- **Execution guide:** `docs/DNS_MIGRATION_EXECUTION.md` (detailed)
- **Full migration plan:** `terraform/DNS_MIGRATION_PLAN.md` (4-week plan)
- **DNS config:** `config/dns_zones.yml`
- **DHCP config:** `config/dhcp_scopes.yml`
- **Inventory:** `inventory/raclette/inventory.ini`

---

## Success Criteria

✅ `dig @192.168.20.29 google.com` works  
✅ `dig @192.168.20.29 pve1.lab.klsll.com` returns 192.168.20.100  
✅ Reverse DNS works  
✅ Both web UIs accessible  
✅ You can resolve names from your dev machine  

**Then:** Proceed with K3s deployment! 🚀
