terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc3"
    }
    pihole = {
      source = "ryanwholey/pihole"
      version = "0.2.0"
    }
  }
}

provider "proxmox" {
  # url is the hostname (FQDN if you have one) for the proxmox host you'd like to connect to to issue the commands. my proxmox host is 'prox-1u'. Add /api2/json at the end for the API
  pm_api_url = "https://pve1.klsll.com:8006/api2/json"

  # api token id is in the form of: <username>@pam!<tokenId>
  #pm_api_token_id = "terraform@pam!cheese_press"
  pm_api_token_id = "root@pam!root_terraform"
  # this is the full secret wrapped in quotes. don't worry, I've already deleted this from my proxmox cluster by the time you read this post
  #pm_api_token_secret = "7c792f65-29b7-45f3-9e73-47c04e541baa"
  pm_api_token_secret = "bc55e6bf-af66-43c9-b921-456aad58a94c"

  # leave tls_insecure set to true unless you have your proxmox SSL certificate situation fully sorted out (if you do, you will know)
  pm_tls_insecure = true

  pm_debug = true

          # Setting parallism to 2 to avoid NFS timeouts
  extra_arguments "default" {
    commands =[ "validate", "plan", "apply", "destroy" ]
    arguments = ["-parallelism=2"]
  }
}

provider "pihole" {
  url = "http://dns2.klsll.com"
  api_token = var.dns2_api_key
}
