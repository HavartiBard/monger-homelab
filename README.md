# Monger Homelab Infrastructure

> Infrastructure as Code for homelab DNS, DHCP, and compute resources

## 🏗️ Overview

This repository contains the complete infrastructure definition for the Monger homelab, including:

- **DNS Servers** - Technitium DNS with automated zone management
- **DHCP Servers** - Technitium DHCP with static reservations
- **Compute** - Proxmox VMs managed via Terraform
- **Network** - Multi-VLAN setup (VLAN 20: Homelab, VLAN 30: IoT)
- **Automation** - Ansible playbooks for configuration management
- **CI/CD** - ArgoCD & Tekton pipelines for GitOps deployments ⭐ **NEW**
- **Monitoring** - Prometheus & Grafana for observability ⭐ **NEW**

## 📚 Documentation Index

### Getting Started
- **[Setup Guide](SETUP_GUIDE.md)** - Initial setup and prerequisites
- **[DNS Deployment](terraform/DNS_DEPLOYMENT.md)** - Deploy DNS servers via Terraform
- **[DNS Management Strategy](DNS_MANAGEMENT_STRATEGY.md)** - How DNS zones are managed
- **[CI/CD Quick Start](CICD_README.md)** - GitOps deployment guide ⭐ **NEW**

### CI/CD & DevOps ⭐ **NEW**
- **[CI/CD Strategy](docs/CI_CD_STRATEGY.md)** - Complete GitOps strategy
- **[Implementation Guide](docs/IMPLEMENTATION_GUIDE.md)** - Step-by-step setup
- **[ArgoCD vs Jenkins](docs/ARGOCD_VS_JENKINS.md)** - Technology decision guide
- **[Summary & Next Steps](docs/SUMMARY_AND_NEXT_STEPS.md)** - Executive summary

### Infrastructure Components
- **[Terraform](terraform/)** - VM provisioning and infrastructure
- **[Ansible Playbooks](playbook/)** - Configuration management
- **[Configuration Files](config/)** - DHCP scopes and DNS zones
- **[ArgoCD Applications](argocd/)** - GitOps application definitions ⭐ **NEW**
- **[Tekton Pipelines](tekton/)** - CI/CD pipeline definitions ⭐ **NEW**

### Operations
- **[Backup & Restore](playbook/README_BACKUP_RESTORE.md)** - Backup procedures
- **[IP Cutover Guide](terraform/IP_CUTOVER_GUIDE.md)** - Migrating to legacy IPs

## 🚀 Quick Start

### Prerequisites
- **Ansible** 2.15+ on control node
- **Terraform** 1.0+ for infrastructure provisioning
- **Proxmox VE** cluster (pve1, pve2)
- **SSH access** to all managed nodes

### Deploy DNS Infrastructure

```bash
# 1. Deploy VMs via Terraform
cd terraform
terraform init
terraform apply

# 2. Install Technitium DNS
cd ../playbook
ansible-playbook -i ../inventory/raclette/inventory.ini technitium_dns.yml

# 3. Configure DHCP scopes
ansible-playbook -i ../inventory/raclette/inventory.ini configure_dhcp_api.yml

# 4. Configure DNS zones
ansible-playbook -i ../inventory/raclette/inventory.ini configure_dns_zones.yml
```

### Test DNS Resolution

```bash
# Forward lookup
dig @192.168.20.29 pve1.lab.klsll.com

# Reverse lookup
dig @192.168.20.29 -x 192.168.20.100
```

## 🏗️ Infrastructure Architecture

### Network Layout

```
┌─────────────────────────────────────────────────────────┐
│                    Proxmox Cluster                      │
│  ┌──────────────┐              ┌──────────────┐        │
│  │    pve1      │              │    pve2      │        │
│  │ 192.168.20.100│             │ 192.168.20.101│       │
│  └──────────────┘              └──────────────┘        │
│                                                          │
│  ┌──────────────┐              ┌──────────────┐        │
│  │ technitium-  │              │ technitium-  │        │
│  │    dns1      │◄────HA──────►│    dns2      │        │
│  │ 192.168.20.29│              │ 192.168.20.28│        │
│  │ 192.168.30.29│              │ 192.168.30.28│        │
│  └──────────────┘              └──────────────┘        │
└─────────────────────────────────────────────────────────┘
         │                              │
         ├──── VLAN 20 (Homelab)       │
         │     192.168.20.0/24          │
         │                              │
         └──── VLAN 30 (IoT)            │
               192.168.30.0/24          │
```

### DNS Zones
- **lab.klsll.com** - Homelab services
- **iot.klsll.com** - IoT devices
- **20.168.192.in-addr.arpa** - Reverse zone for VLAN 20
- **30.168.192.in-addr.arpa** - Reverse zone for VLAN 30

### DHCP Scopes
- **VLAN 20**: 192.168.20.50 - 192.168.20.250
- **VLAN 30**: 192.168.30.50 - 192.168.30.250

## 📁 Repository Structure

```
monger-homelab/
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # VM definitions
│   ├── k3s.tfvars         # K3s cluster definition
│   ├── variables.tf       # Terraform variables
│   └── DNS_DEPLOYMENT.md  # Deployment guide
├── playbook/              # Ansible playbooks
│   ├── configure_dhcp_api.yml    # DHCP configuration
│   ├── configure_dns_zones.yml   # DNS zone management
│   ├── technitium_dns.yml        # Install Technitium
│   └── README_BACKUP_RESTORE.md  # Backup procedures
├── argocd/                # ⭐ NEW: GitOps applications
│   ├── applications/      # Application definitions
│   └── projects/          # ArgoCD projects
├── tekton/                # ⭐ NEW: CI/CD pipelines
│   ├── pipelines/         # Pipeline definitions
│   ├── tasks/             # Reusable tasks
│   └── triggers/          # Webhook triggers
├── k8s/                   # ⭐ NEW: Kubernetes manifests
│   ├── base/              # Base configurations
│   └── overlays/          # Environment overlays
├── config/                # Configuration files
│   ├── dhcp_scopes.yml    # DHCP scope definitions
│   └── dns_zones.yml      # DNS zone definitions
├── inventory/             # Ansible inventory
│   └── raclette/
│       └── inventory.ini  # Host definitions
├── docs/                  # ⭐ NEW: Comprehensive documentation
│   ├── CI_CD_STRATEGY.md  # GitOps strategy
│   └── IMPLEMENTATION_GUIDE.md  # Setup guide
└── scripts/               # Utility scripts
    ├── setup-unraid-mount.sh
    └── bootstrap-cicd.sh  # ⭐ NEW: Automated CI/CD setup
```

## 🔧 Common Operations

### Update DHCP Scopes

```bash
# 1. Edit config file
vim config/dhcp_scopes.yml

# 2. Deploy changes
ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_dhcp_api.yml
```

### Add DNS Records

```bash
# 1. Edit zone file
vim config/dns_zones.yml

# 2. Deploy changes
ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_dns_zones.yml
```

### Backup DNS Configuration

```bash
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml
```

### Restore from Backup

```bash
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_backup_restore.yml
```

## 🎯 Design Principles

1. **Infrastructure as Code** - All configuration in version control
2. **Idempotent Operations** - Safe to re-run playbooks
3. **Separation of Concerns** - Static infrastructure vs dynamic state
4. **API-First** - Use Technitium REST API for configuration
5. **Documentation** - Context-based docs near relevant code

## 📖 Key Concepts

### DNS Management
- **Static records** managed via `dns_zones.yml` (infrastructure)
- **Dynamic records** auto-created by DHCP (clients)
- See [DNS Management Strategy](DNS_MANAGEMENT_STRATEGY.md) for details

### DHCP Configuration
- **Scopes** defined in `dhcp_scopes.yml`
- **Static reservations** for infrastructure
- **Failover** configured between dns1 and dns2

### IP Migration
- Currently using temporary IPs (.28, .29)
- Will migrate to legacy IPs (.2, .3) after testing
- See [IP Cutover Guide](terraform/IP_CUTOVER_GUIDE.md)

## 🔗 Useful Links

- [Technitium DNS Documentation](https://technitium.com/dns/)
- [Technitium API Docs](https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)

## 📝 License

Personal homelab infrastructure - use at your own risk! 🏠
