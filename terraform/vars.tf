variable "ssh_key" {
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJsd0qieGX7cTG6k0xSlECmD8F8a+jYlfBW68xUMMQMG"
}

variable "vm_password" {
  description = "Default password for VMs and LXC containers"
  type        = string
  sensitive   = true
  default     = "cpQhFJ*39"  # Change this or set via TF_VAR_vm_password
}

variable pm_api_token_secret {
  description = "The secret token for the Proxmox API"
  # Loaded from 1Password via 1password.tf
  default = ""
}
variable "proxmox_host" {
    description = "List of Proxmox hosts"
    type = list(string)
    default = ["pve1", "pve2"]
}

variable "template_name" {
    type = string
    description = "Name of the cloud init template"
    default = "ubuntu-2404-cloudinit-template"
}

variable "dns1_api_key" {
    # Loaded from 1Password via 1password.tf
    default = ""
}
variable "dns2_api_key" {
    # Loaded from 1Password via 1password.tf
    default = ""
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

variable "dns_vms" {
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

variable "dns_use_legacy_ips" {
    type        = bool
    description = "Use legacy DNS IPs (192.168.20.2/3) instead of new IPs (192.168.20.28/29)"
    default     = false  # Start with temp IPs, switch to true for cutover
}

# Software versions for consistency across infrastructure
variable "software_versions" {
    type = object({
        ansible_core    = string
        python_min      = string
        technitium_dns  = string
        ubuntu_lts      = string
    })
    description = "Standard software versions used across the homelab"
    default = {
        ansible_core    = "2.17"      # Ansible core version
        python_min      = "3.10"      # Minimum Python version
        technitium_dns  = "latest"    # Technitium DNS version
        ubuntu_lts      = "22.04"     # Ubuntu LTS version
    }
}