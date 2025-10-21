# K3s Hybrid Deployment - Proxmox + Unraid
# Optimized for resource-constrained Proxmox with abundant Unraid resources
#
# Deployment:
# - 1 K3s server on Proxmox pve2 (control plane)
# - 3 K3s agents on Unraid via Docker (workers)
#
# Proxmox Impact: 2GB RAM, 2 cores
# Unraid Impact: 12GB RAM (of 60.6GB available)

vms = [
  {
    name        = "k3s-server"
    desc        = "K3s Control Plane Server (Hybrid with Unraid agents)"
    target_node = "pve2"  # Has slightly more free RAM
    ip          = "dhcp"
    memory      = 2048    # 2GB - minimal for control plane
    cores       = 2
    disk_size   = "20G"
    tags        = "k3s;server;hybrid"
  }
]

# Note: Worker nodes run on Unraid as Docker containers
# See: /mnt/user/appdata/k3s-agents/docker-compose.yml
# 
# After deploying this VM:
# 1. Get K3s token: ssh james@k3s-server "sudo cat /var/lib/rancher/k3s/server/node-token"
# 2. Deploy Unraid agents (see docs/UNRAID_K3S_SETUP.md)
# 3. Verify cluster: kubectl get nodes
