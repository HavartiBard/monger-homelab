terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc3"
    }
  }
}

provider "proxmox" {
  # url is the hostname (FQDN if you have one) for the proxmox host you'd like to 
  # connect to to issue the commands. my proxmox host is 'prox-1u'. 
  # Add /api2/json at the end for the API
  pm_api_url = "https://pve1.klsll.com:8006/api2/json"

  # api token id is in the form of: <username>@pam!<tokenId>
  pm_api_token_id = "root@pam!terraform_admin"
  pm_api_token_secret = var.pm_api_token_secret

  # Setting pm_tls_insecure to true because the Proxmox SSL certificate is not fully configured.
  # This exposes the connection to security risks, so ensure this is necessary.
  pm_tls_insecure = true
  # Setting pm_debug to true for detailed logging. Ensure this is necessary as it can expose sensitive information.
  pm_debug = true
}
