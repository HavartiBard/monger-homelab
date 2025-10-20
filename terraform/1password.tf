terraform {
  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 2.0"
    }
  }
}

# Configure 1Password provider
provider "onepassword" {
  # Uses OP_SERVICE_ACCOUNT_TOKEN environment variable
  # Or run: eval $(op signin) before terraform commands
}

# Read secrets from 1Password
data "onepassword_item" "technitium_dns1" {
  vault = "homelab"
  title = "technitium-dns1"
}

data "onepassword_item" "technitium_dns2" {
  vault = "homelab"
  title = "technitium-dns2"
}

data "onepassword_item" "proxmox" {
  vault = "homelab"
  title = "proxmox"
}

# Export as local variables for use in other .tf files
locals {
  dns1_api_token      = data.onepassword_item.technitium_dns1.password
  dns2_api_token      = data.onepassword_item.technitium_dns2.password
  proxmox_token_secret = data.onepassword_item.proxmox.password
}
