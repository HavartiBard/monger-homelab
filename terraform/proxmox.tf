resource "proxmox_vm_qemu" "k3s" {

    for_each = {
      for vm in var.vms : vm.name => vm
    }

    name = each.value.name
    desc = each.value.desc
    target_node = each.value.target_node

    # The destination resource pool for the new VM
    # pool = "pool0"

    # The template name to clone this vm from
    clone = var.template_name
    full_clone = true
    clone_wait = 15  # Wait 15 seconds after cloning to avoid storage locks

    cores   = each.value.cores
    memory  = each.value.memory
    tags    = each.value.tags

    # Activate QEMU agent for this VM
    agent = 1
    additional_wait = 10  # Additional wait time to avoid storage contention

    os_type = "cloud-init"
    #sockets = 1
    #vcpus = 0
    cpu = "host"
    #memory = 2048
    
    scsihw = "virtio-scsi-pci"
    ciuser = "james"

    sshkeys = <<EOF
    ${var.ssh_key}
    EOF

    # Setup the network interface
    network {
        model = "virtio"
        bridge = "vmbr0"
    }
    # Network configs
    skip_ipv6 = true
    ipconfig0 = "ip=dhcp"  
    searchdomain = "klsll.com"
    nameserver = "192.168.20.2"

    # Setup the EFI Disk for UEFI boot
    efidisk {
        storage = "local-zfs"
        efitype = "4m"
    }
    bios = "ovmf"

    # Ensure the cloned root disk stays attached on virtio0 and the cloud-init ISO lives on local storage.
    disks {
        virtio {
            virtio0 {
                disk {
                    storage = "local-zfs"
                    size    = each.value.disk_size
                }
            }
        }
        ide {
            ide3 {
                cloudinit {
                    storage = "local-zfs"
                }
            }
        }
    }

    # Force Proxmox to boot from the root disk instead of the (detached) cloud-init ISO.
    boot = "order=virtio0"
}

# DNS Server VMs - separate from k3s cluster
resource "proxmox_vm_qemu" "dns" {

    for_each = {
      for vm in var.dns_vms : vm.name => vm
    }

    name = each.value.name
    desc = each.value.desc
    target_node = each.value.target_node

    # The template name to clone this vm from
    clone = var.template_name
    full_clone = true
    clone_wait = 15  # Wait 15 seconds after cloning to avoid storage locks

    cores   = each.value.cores
    memory  = each.value.memory
    tags    = each.value.tags

    # Activate QEMU agent for this VM
    agent = 1
    additional_wait = 10  # Additional wait time to avoid storage contention

    os_type = "cloud-init"
    cpu = "host"
    
    scsihw = "virtio-scsi-pci"
    ciuser = "james"

    sshkeys = <<EOF
    ${var.ssh_key}
    EOF

    # Setup the network interfaces for DNS servers
    # Primary interface - Native/Untagged (Homelab VLAN 20)
    network {
        model = "virtio"
        bridge = "vmbr0"
        # No tag = native/untagged VLAN
    }
    # Secondary interface - VLAN 30 (IoT)
    network {
        model = "virtio"
        bridge = "vmbr0"
        tag = 30
    }
    
    # Network configs
    skip_ipv6 = true
    
    # VLAN 20 interface (ens18)
    # Phase 1 (testing): Use temp static IPs (192.168.20.28/29)
    # Phase 2 (cutover): Use legacy IPs (192.168.20.2/3)
    ipconfig0 = var.dns_use_legacy_ips ? (
        each.value.name == "technitium-dns1" ? "ip=192.168.20.3/24,gw=192.168.20.1" : "ip=192.168.20.2/24,gw=192.168.20.1"
    ) : (
        each.value.name == "technitium-dns1" ? "ip=192.168.20.29/24,gw=192.168.20.1" : "ip=192.168.20.28/24,gw=192.168.20.1"
    )
    
    # VLAN 30 interface (ens19) - Static IP (no gateway - use VLAN 20 as default route)
    # Phase 1 (testing): Use temp IPs (192.168.30.28/29)
    # Phase 2 (cutover): Use legacy IPs (192.168.30.2/3)
    ipconfig1 = var.dns_use_legacy_ips ? (
        each.value.name == "technitium-dns1" ? "ip=192.168.30.3/24" : "ip=192.168.30.2/24"
    ) : (
        each.value.name == "technitium-dns1" ? "ip=192.168.30.29/24" : "ip=192.168.30.28/24"
    )
    
    searchdomain = "klsll.com"
    nameserver = "192.168.20.2"

    # Setup the EFI Disk for UEFI boot
    efidisk {
        storage = "local-zfs"
        efitype = "4m"
    }
    bios = "ovmf"

    # Ensure the cloned root disk stays attached on virtio0 and the cloud-init ISO lives on local storage.
    disks {
        virtio {
            virtio0 {
                disk {
                    storage = "local-zfs"
                    size    = each.value.disk_size
                }
            }
        }
        ide {
            ide3 {
                cloudinit {
                    storage = "local-zfs"
                }
            }
        }
    }

    # Force Proxmox to boot from the root disk instead of the (detached) cloud-init ISO.
    boot = "order=virtio0"
}
