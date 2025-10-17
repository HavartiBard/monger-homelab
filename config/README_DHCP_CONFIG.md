# DHCP Configuration Management

## Overview
DHCP configuration is managed as Infrastructure as Code using Ansible and version-controlled in Git.

## Architecture

```
config/dhcp_scopes.yml          → Source of truth (edit this)
         ↓
playbook/deploy_dhcp_config.yml → Deployment automation
         ↓
templates/dhcp_scopes.json.j2   → Template for JSON config
         ↓
Both DNS Servers                → Identical configuration
```

## Configuration File

**File:** `config/dhcp_scopes.yml`

This file defines:
- ✅ DHCP scopes for each VLAN
- ✅ IP ranges and lease times
- ✅ Gateway and DNS servers
- ✅ Static reservations
- ✅ Failover configuration
- ✅ Server roles

## Making Changes

### 1. Edit Configuration
```bash
# Edit the config file
vim config/dhcp_scopes.yml
```

### 2. Update DHCP Scopes
Add/modify scopes:
```yaml
dhcp_scopes:
  - name: "New VLAN"
    network: "192.168.40.0"
    subnet_mask: "255.255.255.0"
    start_ip: "192.168.40.50"
    end_ip: "192.168.40.250"
    lease_time: "86400"
    gateway: "192.168.40.1"
    dns_servers:
      - "192.168.20.29"
      - "192.168.20.28"
    domain_name: "newvlan.klsll.com"
    enabled: false
    reservations: []
```

### 3. Add Static Reservations
```yaml
reservations:
  - hostname: "my-server"
    mac_address: "AA:BB:CC:DD:EE:FF"
    ip_address: "192.168.20.100"
```

### 4. Deploy Changes
```bash
cd /mnt/d/cluster/monger-homelab

# Deploy to both DNS servers
ansible-playbook -i inventory/raclette/inventory.ini playbook/deploy_dhcp_config.yml

# Or deploy to specific server
ansible-playbook -i inventory/raclette/inventory.ini playbook/deploy_dhcp_config.yml --limit technitium-dns1
```

### 5. Apply in Web UI
The playbook generates the configuration file, but you still need to manually create scopes in the Technitium web UI:

1. Log into http://192.168.20.29:5380 (or .28)
2. Go to **DHCP** → **Scopes**
3. Click **Add Scope**
4. Use values from `config/dhcp_scopes.yml`
5. Repeat for all scopes
6. Configure failover

## Benefits of This Approach

### ✅ Version Control
- All changes tracked in Git
- Easy rollback to previous configs
- Audit trail of who changed what

### ✅ Consistency
- Both servers get identical configuration
- No manual copy/paste errors
- Single source of truth

### ✅ Documentation
- Config file is self-documenting
- Comments explain each setting
- Easy to understand network layout

### ✅ Automation
- One command deploys to all servers
- Repeatable and reliable
- No SSH into containers needed

### ✅ Disaster Recovery
- Rebuild servers from scratch
- Run playbook to restore config
- Back in business quickly

## Workflow

### Initial Setup
```bash
# 1. Edit config with your network details
vim config/dhcp_scopes.yml

# 2. Update MAC addresses for reservations
# 3. Set strong failover password
# 4. Deploy to servers
ansible-playbook -i inventory/raclette/inventory.ini playbook/deploy_dhcp_config.yml

# 5. Manually create scopes in web UI using the config values
# 6. Enable failover
# 7. Test DHCP on both VLANs
```

### Making Changes
```bash
# 1. Edit config
vim config/dhcp_scopes.yml

# 2. Commit to Git
git add config/dhcp_scopes.yml
git commit -m "Add new DHCP reservation for server X"
git push

# 3. Deploy changes
ansible-playbook -i inventory/raclette/inventory.ini playbook/deploy_dhcp_config.yml

# 4. Update scopes in web UI if needed
```

## Current Configuration

### VLAN 20 - Homelab
- **Network:** 192.168.20.0/24
- **Range:** 192.168.20.50 - 192.168.20.250
- **Gateway:** 192.168.20.1
- **DNS:** 192.168.20.29, 192.168.20.28
- **Domain:** lab.klsll.com

### VLAN 30 - IoT
- **Network:** 192.168.30.0/24
- **Range:** 192.168.30.50 - 192.168.30.250
- **Gateway:** 192.168.30.1
- **DNS:** 192.168.30.29, 192.168.30.28
- **Domain:** iot.klsll.com

## Failover Configuration

- **Primary:** 192.168.20.29 (technitium-dns1)
- **Secondary:** 192.168.20.28 (technitium-dns2)
- **Shared Secret:** Set in `config/dhcp_scopes.yml`

## Important Notes

⚠️ **Manual Steps Required:**
- Technitium doesn't have a full API for DHCP scope creation
- You must manually create scopes in the web UI
- The config file serves as documentation and reference
- Future: Could use Technitium API if available

⚠️ **Security:**
- Keep `dhcp_scopes.yml` secure (contains network layout)
- Use strong failover shared secret
- Rotate secrets periodically

⚠️ **Testing:**
- Always test DHCP changes in maintenance window
- Have rollback plan ready
- Monitor DHCP lease logs

## Troubleshooting

### Config not deploying
```bash
# Check Ansible connectivity
ansible -i inventory/raclette/inventory.ini technitium_dns -m ping

# Run playbook with verbose output
ansible-playbook -i inventory/raclette/inventory.ini playbook/deploy_dhcp_config.yml -vvv
```

### Scopes not matching
```bash
# View generated config
ssh james@192.168.20.29 "cat /opt/technitium/config/dhcp_scopes.json"

# Compare with source
cat config/dhcp_scopes.yml
```

## Future Enhancements

- [ ] Automate scope creation via Technitium API
- [ ] Add validation checks for IP ranges
- [ ] Create backup/restore for DHCP config
- [ ] Add monitoring for DHCP lease utilization
- [ ] Integrate with network documentation

---

**Last Updated:** 2025-01-16
**Maintained By:** Infrastructure Team
