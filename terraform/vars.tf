variable "ssh_key" {
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJsd0qieGX7cTG6k0xSlECmD8F8a+jYlfBW68xUMMQMG"
}

variable "proxmox_host" {
    description = "List of Proxmox hosts"
    type = list(string)
    default = ["pve1", "pve2"]
}

variable "template_name" {
    type = string
    description = "Name of the cloud init template"
    default = "ubuntu-2404-cloudinit"
}

variable "dns1_api_key" {
    default = "1e44965fc0ed299793edbe805ec6b6441a2830bb620e98f8ffedcc0d0aa6fb31"
}
variable "dns2_api_key" {
    default = "3e4a7e8ebe2eade594d21a5bd01fe9afb0fb1c0a8a467645a764f209c5208a68"
}

variable "vms" {
    type = list(object({
        name        = string
        desc        = string
        target_node = string
        ip          = string
        tags        = string
        memory      = number
        cores       = number
        disk_size   = string
    }))
    default = []
}