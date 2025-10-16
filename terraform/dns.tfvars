dns_vms = [
    {
        name        = "technitium-dns1"
        desc        = "Technitium DNS Server 1 (Primary)"
        target_node = "pve1"
        ip          = "dhcp"
        memory      = 1024
        cores       = 2
        disk_size   = "10G"
        tags        = "dns,technitium,infrastructure"
    },
    {
        name        = "technitium-dns2"
        desc        = "Technitium DNS Server 2 (Secondary)"
        target_node = "pve2"
        ip          = "dhcp"
        memory      = 1024
        cores       = 2
        disk_size   = "10G"
        tags        = "dns,technitium,infrastructure"
    }
]
