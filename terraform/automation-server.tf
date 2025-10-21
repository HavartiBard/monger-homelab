# Automation Server for Ansible/Cron Jobs
# Lightweight VM to run periodic automation tasks

resource "proxmox_vm_qemu" "automation_server" {
  count       = 0  # Set to 1 to enable
  name        = "automation-server"
  target_node = "pve1"
  
  # Clone from Ubuntu Cloud template
  clone = "ubuntu-cloud-template"
  
  # Minimal resources
  cores   = 1
  sockets = 1
  memory  = 1024  # 1GB RAM
  
  # Small disk
  disks {
    scsi {
      scsi0 {
        disk {
          size    = "10G"
          storage = "local-lvm"
        }
      }
    }
  }
  
  # Network
  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 20  # VLAN 20
  }
  
  # Static IP via cloud-init
  ipconfig0 = "ip=192.168.20.50/24,gw=192.168.20.1"
  
  # Cloud-init config
  ciuser     = "ansible"
  cipassword = local.vm_password
  sshkeys    = local.ssh_public_key
  
  # Start on boot
  onboot = true
  
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

output "automation_server_ip" {
  value = proxmox_vm_qemu.automation_server[*].default_ipv4_address
}
