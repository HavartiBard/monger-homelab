vms = [
    {
        name        = "k3s-controller-1"
        desc        = "Kubernetes Control Plane Node 1"
        target_node = "pve1"
        ip          = "dhcp"
        memory      = 4096
        cores       = 4
        disk_size   = "32G"
        tags        = "k3s,controller"
    },
    {
        name        = "k3s-controller-2"
        desc        = "Kubernetes Control Plane Node 2"
        target_node = "pve2"
        ip          = "dhcp"
        memory      = 4096
        cores       = 4
        disk_size   = "32G"
        tags        = "k3s,controller"
    },
    {
        name        = "k3s-controller-3"
        desc        = "Kubernetes Control Plane Node 3"
        target_node = "pve2"
        ip          = "dhcp"
        memory      = 4096
        cores       = 4
        disk_size   = "32G"
        tags        = "k3s,controller"
    },
    {
        name        = "k3s-worker-1"
        desc        = "Kubernetes Worker Node 1"
        target_node = "pve1"
        ip          = "dhcp"
        memory      = 4096
        cores       = 2
        disk_size   = "120G"
        tags        = "k3s,worker"
    },
    {
        name        = "k3s-worker-2"
        desc        = "Kubernetes Worker Node 2"
        target_node = "pve1"
        ip          = "dhcp"
        memory      = 4096
        cores       = 2
        disk_size   = "120G"
        tags        = "k3s,worker"
    },
    {
        name        = "k3s-worker-3"
        desc        = "Kubernetes Worker Node 3"
        target_node = "pve2"
        ip          = "dhcp"
        memory      = 4096
        cores       = 2
        disk_size   = "120G"
        tags        = "k3s,worker"
    },
    {
        name        = "k3s-worker-4"
        desc        = "Kubernetes Worker Node 4"
        target_node = "pve2"
        ip          = "dhcp"
        memory      = 4096
        cores       = 2
        disk_size   = "120G"
        tags        = "k3s,worker"
    }
    ]