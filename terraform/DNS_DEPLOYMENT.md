# DNS Server Deployment Plan

## Overview
This document outlines the process to deploy new Technitium DNS servers using Terraform and migrate from the old VM 103.

## Current State
- **dns1 (VM 100)**: Running on pve2 - Technitium DNS (production)
- **pihole2 (VM 102)**: Running on pve1 - Old Pi-hole (to be decommissioned)
- **technitiumdns (VM 103)**: Running on pve1 - Technitium DNS (to be replaced)

## New Infrastructure
- **dns1-new**: Will be deployed on pve1 (1GB RAM, 2 cores, 10GB disk)
- **dns2-new**: Will be deployed on pve2 (1GB RAM, 2 cores, 10GB disk)

## Deployment Steps

### Phase 1: Deploy New DNS Servers ✅ COMPLETED
```bash
cd d:\cluster\monger-homelab\terraform

# Deploy the new DNS VMs
terraform apply -var-file="dns.tfvars" -parallelism=1
```

**Status:** 
- ✅ technitium-dns1 (VM 105) on pve1 - 192.168.20.29
- ✅ technitium-dns2 (VM 106) on pve2 - 192.168.20.28

### Phase 2: Install Technitium DNS with Ansible ✅ COMPLETED
```bash
cd d:\cluster\monger-homelab

# Install Technitium DNS on both servers
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_dns.yml
```

**Deployed:**
- Technitium DNS version: `latest`
- Docker containers running on both VMs
- systemd-resolved disabled (to free port 53)
- Web interfaces accessible

**Access:**
- http://192.168.20.29:5380 (dns1)
- http://192.168.20.28:5380 (dns2)
- Default login: admin/admin ⚠️ **CHANGE THIS IMMEDIATELY!**

### Phase 3: Configure Technitium (TODO)
Next steps:
1. ⚠️ Log into web interface on both servers and change admin password
2. Configure DNS zones and forwarders
3. Set up zone replication between servers
4. Test DNS resolution
5. Update DHCP to point clients to new DNS servers

### Phase 3: Cutover
1. Update DHCP/network configs to point to new DNS servers
2. Verify all clients are using new DNS
3. Monitor for 24-48 hours

### Phase 4: Cleanup
Once stable:
```bash
# Destroy old VMs (VM 102, VM 103)
# This will be done manually in Proxmox UI
```

## Rollback Plan
If issues occur:
1. Revert DHCP/network configs to old DNS servers
2. Keep old VMs running until new ones are stable
3. Destroy new VMs if needed: `terraform destroy -var-file="dns.tfvars"`

## Notes
- The new VMs will use cloud-init for initial setup
- SSH keys are automatically configured
- VMs will get IPs via DHCP initially
- Consider setting static IPs for DNS servers after deployment
