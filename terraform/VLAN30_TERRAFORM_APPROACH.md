# VLAN 30 Configuration via Terraform

## Decision: Use Terraform for Network Configuration ✅

We've chosen to configure VLAN 30 interfaces in Terraform rather than Ansible for these reasons:

### Why Terraform?
1. **Infrastructure as Code**: Network config is part of VM definition
2. **Reproducible**: VMs are always deployed with correct network config
3. **Version Controlled**: Network changes tracked in git
4. **Immutable Infrastructure**: No configuration drift
5. **Disaster Recovery**: One `terraform apply` rebuilds everything correctly

### What Changed?

**File**: `terraform/proxmox.tf`

Added to the `dns` resource block:
```hcl
# Setup the network interfaces for DNS servers
# Primary interface - VLAN 20 (Homelab)
network {
    model = "virtio"
    bridge = "vmbr0"
    tag = 20
}
# Secondary interface - VLAN 30 (IoT)
network {
    model = "virtio"
    bridge = "vmbr0"
    tag = 30
}

# Network configs
skip_ipv6 = true
# VLAN 20 interface (ens18) - DHCP initially
ipconfig0 = "ip=dhcp"
# VLAN 30 interface (ens19) - Static IP based on VM name
ipconfig1 = each.value.name == "technitium-dns1" ? "ip=192.168.30.29/24,gw=192.168.30.1" : "ip=192.168.30.28/24,gw=192.168.30.1"
```

## Network Configuration Details

### DNS Server IPs

| Server | VLAN 20 (Homelab) | VLAN 30 (IoT) | Interface |
|--------|-------------------|---------------|-----------|
| technitium-dns1 | 192.168.20.29 (DHCP) | 192.168.30.29/24 (Static) | ens18 / ens19 |
| technitium-dns2 | 192.168.20.28 (DHCP) | 192.168.30.28/24 (Static) | ens18 / ens19 |

### VLAN Tags
- **VLAN 20**: Homelab network (192.168.20.0/24)
- **VLAN 30**: IoT network (192.168.30.0/24)

### Gateways
- **VLAN 20**: 192.168.20.1
- **VLAN 30**: 192.168.30.1

## Deployment Options

### Option 1: Recreate VMs (Clean Slate) ✅ **RECOMMENDED**

This ensures VMs are built exactly as defined in Terraform.

```bash
cd /mnt/d/cluster/monger-homelab/terraform

# Destroy existing DNS VMs
terraform destroy -var-file="dns.tfvars" -target=proxmox_vm_qemu.dns

# Recreate with VLAN 30 interfaces
terraform apply -var-file="dns.tfvars" -target=proxmox_vm_qemu.dns -parallelism=1

# Run Ansible to install Technitium
cd /mnt/d/cluster/monger-homelab
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_dns.yml

# Restore backup if you already had configuration
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml
```

**Pros:**
- ✅ Clean, reproducible infrastructure
- ✅ VMs match Terraform state exactly
- ✅ No manual configuration needed
- ✅ Cloud-init configures VLAN 30 automatically

**Cons:**
- ⚠️ Requires VM downtime (~10 minutes)
- ⚠️ Need to restore configuration from backup

### Option 2: Keep Existing VMs, Use Ansible

If you want to keep the current VMs running:

```bash
cd /mnt/d/cluster/monger-homelab

# Configure VLAN 30 on existing VMs
ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_vlan30.yml
```

**Pros:**
- ✅ No downtime
- ✅ Keep existing configuration

**Cons:**
- ❌ Configuration drift (Terraform doesn't know about Ansible changes)
- ❌ If VMs are rebuilt, VLAN 30 won't be there (unless you remember to run Ansible)
- ❌ Two sources of truth (Terraform + Ansible)

## My Recommendation

**Use Option 1 (Recreate VMs)** because:

1. **You just deployed these VMs** - they're fresh, minimal configuration to lose
2. **You have backups** - can restore DNS config easily
3. **Clean slate** - ensures everything matches your Terraform code
4. **Future-proof** - if you ever need to rebuild, it's one command

## Step-by-Step: Recreate VMs with VLAN 30

### Step 1: Backup Current Configuration (if needed)
```bash
cd /mnt/d/cluster/monger-homelab

# Backup new DNS servers (if you've configured anything)
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml
```

### Step 2: Destroy Existing DNS VMs
```bash
cd /mnt/d/cluster/monger-homelab/terraform

# Destroy only DNS VMs (not k3s)
terraform destroy -var-file="dns.tfvars" -target=proxmox_vm_qemu.dns

# Confirm: yes
```

### Step 3: Recreate with VLAN 30
```bash
# Apply Terraform with new network config
terraform apply -var-file="dns.tfvars" -target=proxmox_vm_qemu.dns -parallelism=1

# Confirm: yes
```

This will create:
- VM 105 (technitium-dns1) with:
  - ens18: VLAN 20, DHCP (will get 192.168.20.29)
  - ens19: VLAN 30, Static 192.168.30.29/24
  
- VM 106 (technitium-dns2) with:
  - ens18: VLAN 20, DHCP (will get 192.168.20.28)
  - ens19: VLAN 30, Static 192.168.30.28/24

### Step 4: Run Ansible to Install Technitium
```bash
cd /mnt/d/cluster/monger-homelab

# Install Technitium DNS
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_dns.yml
```

### Step 5: Restore Configuration (if needed)
```bash
# If you backed up legacy DNS config
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml
```

### Step 6: Verify VLAN 30
```bash
# Check interfaces
ssh james@192.168.20.29 "ip addr show"
ssh james@192.168.20.28 "ip addr show"

# Should see ens19 with 192.168.30.29 and 192.168.30.28

# Test DNS on VLAN 30
dig @192.168.30.29 google.com
dig @192.168.30.28 google.com

# Test connectivity
ssh james@192.168.20.29 "ping -c 3 192.168.30.1"
```

## Verification Checklist

After recreation:
- [ ] VMs have two network interfaces (ens18, ens19)
- [ ] ens18 has VLAN 20 IP (192.168.20.29/28)
- [ ] ens19 has VLAN 30 IP (192.168.30.29/28)
- [ ] Can ping VLAN 30 gateway (192.168.30.1)
- [ ] DNS resolves on both VLANs
- [ ] Technitium web UI accessible
- [ ] Configuration restored (if applicable)

## Ansible Playbook Status

The `configure_vlan30.yml` playbook is still available if you need it, but with Terraform handling the network config, you **don't need to run it**.

Keep it as a backup option or for troubleshooting.

## Future Changes

To modify network configuration:
1. Edit `terraform/proxmox.tf`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes
4. Commit changes to git

**No need to remember Ansible commands** - it's all in code!

## Rollback Plan

If something goes wrong:
1. Revert `proxmox.tf` to previous version
2. Run `terraform apply` to restore old config
3. Or use Ansible playbook as fallback

## Summary

✅ **Terraform approach chosen** for network configuration
✅ **VLAN 30 interfaces** defined in `proxmox.tf`
✅ **Static IPs** configured via cloud-init
✅ **Reproducible** infrastructure
✅ **Ready to recreate VMs** with proper network config

---

**Next Step**: Decide if you want to recreate VMs now or keep existing ones and use Ansible.

**My recommendation**: Recreate VMs - it's cleaner and more maintainable long-term.
