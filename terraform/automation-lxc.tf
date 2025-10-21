# Automation LXC Container for Ansible/Cron Jobs
# Lightweight container to run periodic automation tasks

resource "proxmox_lxc" "automation" {
  target_node  = "pve1"
  hostname     = "automation"
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  password     = local.vm_password
  unprivileged = true
  
  # Create non-root user
  # Note: LXC doesn't support this directly, we'll handle in bootstrap
  
  # Minimal resources
  cores  = 1
  memory = 512  # 512MB RAM is plenty for Ansible
  swap   = 512
  
  # Root filesystem
  rootfs {
    storage = "local-lvm"
    size    = "8G"
  }
  
  # Network configuration
  network {
    name   = "eth0"
    bridge = "vmbr0"
    # No VLAN tag - VLAN 20 is native/untagged
    ip     = "192.168.20.50/24"
    gw     = "192.168.20.1"
  }
  
  # DNS settings
  nameserver = "192.168.20.29 192.168.20.28"
  searchdomain = "lab.klsll.com"
  
  # SSH key
  ssh_public_keys = local.ssh_public_key
  
  # Start on boot
  onboot = true
  start  = true
  
  # Features
  features {
    nesting = true  # Allow Docker if needed later
    # mount = "nfs" - Set manually: ssh root@192.168.20.100 "pct set 104 -features nesting=1,mount=nfs"
  }
  
  lifecycle {
    ignore_changes = [
      network,
      features,  # Ignore feature changes - mount=nfs set manually
    ]
  }
}

output "automation_lxc_ip" {
  value       = "192.168.20.50"
  description = "Automation LXC container IP"
}
