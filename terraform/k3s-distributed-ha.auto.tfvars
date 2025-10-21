# K3s Distributed HA Deployment - Maximum Resilience
# Control planes distributed across ALL physical hosts
#
# Architecture:
# - 1 K3s server on pve1 (VM)
# - 1 K3s server on pve2 (VM)
# - 1 K3s server on Unraid (Docker container)
# - 5 K3s workers on Unraid (Docker containers)
#
# Resilience: Can survive ENTIRE HOST FAILURE (any single host)
# Proxmox Impact: 4GB RAM total (2GB per node)
# Unraid Impact: 24GB RAM (1 server + 5 workers)

vms = [
  # Control Plane Node 1 on pve1
  {
    name        = "k3s-server-1"
    desc        = "K3s Control Plane 1 (HA - Distributed across hosts)"
    target_node = "pve1"
    ip          = "dhcp"
    memory      = 2048    # 2GB
    cores       = 2
    disk_size   = "20G"
    tags        = "k3s;server;control-plane;ha;distributed"
  },
  
  # Control Plane Node 2 on pve2
  {
    name        = "k3s-server-2"
    desc        = "K3s Control Plane 2 (HA - Distributed across hosts)"
    target_node = "pve2"
    ip          = "dhcp"
    memory      = 2048    # 2GB
    cores       = 2
    disk_size   = "20G"
    tags        = "k3s;server;control-plane;ha;distributed"
  }
]

# Third control plane runs on Unraid as a Docker container
# See: /mnt/user/appdata/k3s-cluster/docker-compose.yml
# 
# Worker nodes also run on Unraid
#
# Installation Order:
# 1. Deploy 2 VMs with Terraform (pve1, pve2)
# 2. Install K3s on server-1 (pve1) with --cluster-init
# 3. Install K3s on server-2 (pve2) to join server-1
# 4. Deploy server-3 on Unraid via Docker (joins cluster)
# 5. Deploy 5 workers on Unraid via Docker
# 6. Verify: kubectl get nodes (should show 8 nodes across 3 hosts)
#
# High Availability Features:
# - Survives ANY SINGLE HOST failure (Unraid, pve1, or pve2)
# - Survives Unraid updates (pve1+pve2 maintain quorum)
# - Survives Proxmox updates (one at a time, Unraid maintains quorum)
# - True geographic distribution
# - Maximum resilience for minimal resources
