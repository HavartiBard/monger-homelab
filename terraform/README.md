# Terraform Homelab Infrastructure

## Deployment Commands

### DNS Servers Only
```bash
terraform apply -var-file="dns.tfvars" -parallelism=1
```

### K3s Cluster Only
```bash
terraform apply -var-file="k3s.tfvars" -parallelism=2
```

### Both DNS and K3s
```bash
terraform apply -var-file="dns.tfvars" -var-file="k3s.tfvars" -parallelism=2
```

## Storage Lock Prevention

To avoid NFS storage lock issues:

1. **Use `-parallelism=1` or `-parallelism=2`** to limit concurrent operations
2. **Clone wait times** are configured (15 seconds) in `proxmox.tf`
3. **Additional wait** (10 seconds) after VM creation
4. **Deploy in batches** if creating many VMs

## Troubleshooting Storage Locks

If you encounter storage locks:

```bash
# Check NFS mounts on Proxmox nodes
ssh james@192.168.20.100 "df -h | grep nfs"
ssh james@192.168.20.101 "df -h | grep nfs"

# Remount if needed
ssh james@192.168.20.100 "mount -a"
ssh james@192.168.20.101 "mount -a"

# Check for stale locks
ssh james@192.168.20.100 "pvesm status"
ssh james@192.168.20.101 "pvesm status"
```

## File Structure

- `terraform.tfvars` - Default variables (currently empty, k3s VMs disabled)
- `dns.tfvars` - DNS server configuration
- `k3s.tfvars` - K3s cluster configuration
- `proxmox.tf` - VM resource definitions
- `vars.tf` - Variable declarations
- `provider.tf` - Provider configuration
