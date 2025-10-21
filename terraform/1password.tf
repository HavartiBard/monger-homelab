# Read secrets from 1Password using service account token
# Provider configuration is in provider.tf
# Set OP_SERVICE_ACCOUNT_TOKEN environment variable before running terraform

data "onepassword_item" "technitium_dns1" {
  vault = "homelab"
  title = "Technitium DNS1 API"
}

data "onepassword_item" "technitium_dns2" {
  vault = "homelab"
  title = "Technitium DNS2 API"
}

data "onepassword_item" "proxmox" {
  vault = "homelab"
  title = "Proxmox Terraform"
}

data "onepassword_item" "vm_default" {
  vault = "homelab"
  title = "Homelab VM Default"
}

data "onepassword_item" "ssh_key" {
  vault = "homelab"
  title = "Spraycheese Infrastructure SSH Key"
}

#data "onepassword_item" "dhcp_failover" {
#  vault = "homelab"
#  title = "Technitium DHCP Failover"
#}

# Export as local variables for use in other .tf files
locals {
  dns1_api_token       = data.onepassword_item.technitium_dns1.credential
  dns2_api_token       = data.onepassword_item.technitium_dns2.credential
  proxmox_token_secret = data.onepassword_item.proxmox.credential
  vm_password          = data.onepassword_item.vm_default.password
#  dhcp_failover_secret = data.onepassword_item.dhcp_failover.password
  ssh_public_key       = data.onepassword_item.ssh_key.public_key
}
