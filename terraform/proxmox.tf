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

    cores   = each.value.cores
    memory  = each.value.memory
    tags    = each.value.tags

    # Activate QEMU agent for this VM
    agent = 1

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
    nameserver = "192.168.20.2,192.168.1.2"

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
        virtio {
            virtio0 {
                disk {
                    size            = 32
                    cache           = "writeback"
                    storage         = "local-zfs"
                    iothread        = true
                    discard         = true
                }
            }
        }
    }

    # Setup the ip address using cloud-init.
    boot = "order=virtio0"
}

# Create a DNS record for the kube-controller VMs
resource "pihole_dns_record" "k3s" {
    for_each = proxmox_vm_qemu.k3s

    domain = "${each.value.name}.klsll.com"
    ip = proxmox_vm_qemu.k3s[each.key].default_ipv4_address
}