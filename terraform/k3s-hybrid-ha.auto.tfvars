# K3s Hybrid HA Deployment - 3 Control Planes + Unraid Workers
# High Availability configuration with proper etcd quorum
#
# Deployment:
# - 3 K3s servers on Proxmox (HA control plane with quorum)
#   - 2 on pve1 (distributed for resilience)
#   - 1 on pve2
# - 5 K3s agents on Unraid via Docker (workers)
#
# Proxmox Impact: 6GB RAM, 6 cores (tight but doable)
# Unraid Impact: 20GB RAM (of 60.6GB available - 33% utilization)

vms = [
  # Control Plane Node 1 (Initial server)
  {
    name        = "k3s-server-1"
    desc        = "K3s Control Plane 1 (HA Cluster Leader)"
    target_node = "pve1"
    ip          = "dhcp"
    memory      = 2048    # 2GB
    cores       = 2
    disk_size   = "20G"
    tags        = "k3s;server;control-plane;ha"
  },
  
  # Control Plane Node 2 (Join server 1)
  {
    name        = "k3s-server-2"
    desc        = "K3s Control Plane 2 (HA Member)"
    target_node = "pve1"  # Same node for now, separate if more RAM
    ip          = "dhcp"
    memory      = 2048    # 2GB
    cores       = 2
    disk_size   = "20G"
    tags        = "k3s;server;control-plane;ha"
  },
  
  # Control Plane Node 3 (Join server 1 for quorum)
  {
    name        = "k3s-server-3"
    desc        = "K3s Control Plane 3 (HA Member)"
    target_node = "pve2"  # Different Proxmox node for resilience
    ip          = "dhcp"
    memory      = 2048    # 2GB
    cores       = 2
    disk_size   = "20G"
    tags        = "k3s;server;control-plane;ha"
  }
]

# Note: Worker nodes run on Unraid as Docker containers
# See: /mnt/user/appdata/k3s-agents/docker-compose.yml
# 
# Installation Order:
# 1. Deploy all 3 VMs with Terraform
# 2. Install K3s on server-1 (first server with --cluster-init)
# 3. Install K3s on server-2 and server-3 (join server-1)
# 4. Get K3s token from any server
# 5. Deploy Unraid agents (5 workers)
# 6. Verify cluster: kubectl get nodes (should show 8 nodes)
#
# High Availability:
# - Can lose 1 control plane (2/3 quorum maintained)
# - Can lose multiple workers (5 workers provide redundancy)
# - Workloads automatically rescheduled on node failure
