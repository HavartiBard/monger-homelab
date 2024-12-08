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
    
    provider "pihole" {
    }
