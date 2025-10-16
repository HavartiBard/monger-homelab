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

    # Setup the disk
    disks {
        ide {
            ide3 {
                cloudinit {
                    storage = "local-zfs"
                }
            }
        }
        # NOTE:
        # Do NOT add an extra blank boot disk here. The cloned cloud image
        # provides the OS disk as scsi0. Adding a new virtio0 disk results
        # in an unbootable VM. If you need an additional data disk, add it
        # explicitly under scsi1/scsi2, etc.
    }

    # Setup the ip address using cloud-init.
    boot = "order=scsi0"
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

    # Setup the disk
    disks {
        ide {
            ide3 {
                cloudinit {
                    storage = "local-zfs"
                }
            }
        }
        # NOTE:
        # The cloned cloud image provides the OS disk as scsi0.
        # Do not create a separate virtio0 disk or the VM will try to boot
        # from an empty disk. Add extra data disks as scsi1+ if needed.
    }

    # Setup the ip address using cloud-init.
    boot = "order=scsi0"
}