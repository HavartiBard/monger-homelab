# Credentials Audit & Migration

## Summary

All hardcoded credentials have been moved to 1Password and synced to Ansible Vault.

## Credentials Migrated

### 1. Technitium DNS API Tokens
- **Location**: `config/secrets_mapping.yml`
- **1Password Items**: 
  - `Technitium DNS1 API`
  - `Technitium DNS2 API`
- **Vault Variables**: 
  - `vault_technitium_dns1_token`
  - `vault_technitium_dns2_token`
- **Used In**:
  - `playbook/technitium_api_backup.yml`
  - `playbook/configure_dns_zones.yml`
  - `playbook/configure_dhcp_api.yml`
  - `inventory/raclette/host_vars/technitium-dns*.yml`

### 2. Proxmox API Token
- **Location**: `terraform/1password.tf`
- **1Password Item**: `Proxmox Terraform`
- **Terraform Local**: `local.proxmox_token_secret`
- **Used In**: `terraform/provider.tf`

### 3. VM/LXC Default Password
- **Location**: `config/secrets_mapping.yml`
- **1Password Item**: `Homelab VM Default`
- **Vault Variable**: `vault_vm_default_password`
- **Terraform Local**: `local.vm_password`
- **Used In**:
  - `terraform/automation-server.tf`
  - `terraform/automation-lxc.tf`

### 4. Infrastructure SSH Public Key
- **Location**: `config/secrets_mapping.yml`
- **1Password Item**: `Homelab Infrastructure SSH`
- **Vault Variable**: `vault_ssh_public_key`
- **Terraform Local**: `local.ssh_public_key`
- **Used In**:
  - `terraform/proxmox.tf` (all VMs)
  - `terraform/automation-server.tf`
  - `terraform/automation-lxc.tf`

### 5. DHCP Failover Shared Secret
- **Location**: `config/secrets_mapping.yml`
- **1Password Item**: `Technitium DHCP Failover`
- **Vault Variable**: `vault_dhcp_failover_secret`
- **Used In**: `playbook/configure_dhcp_api.yml`

## Files Modified

### Configuration
- ✅ `config/secrets_mapping.yml` - Added all credential mappings

### Terraform
- ✅ `terraform/vars.tf` - Removed hardcoded values
- ✅ `terraform/1password.tf` - Added 1Password data sources
- ✅ `terraform/proxmox.tf` - Use `local.ssh_public_key`
- ✅ `terraform/automation-server.tf` - Use `local.vm_password` and `local.ssh_public_key`
- ✅ `terraform/automation-lxc.tf` - Use `local.vm_password` and `local.ssh_public_key`

### Ansible Playbooks
- ✅ `playbook/configure_dns_zones.yml` - Use `technitium.api_token` from vault
- ✅ `playbook/configure_dhcp_api.yml` - Use `technitium.api_token` and `vault_dhcp_failover_secret`
- ✅ `inventory/raclette/host_vars/technitium-dns*.yml` - Reference vault variables

## Setup Required in 1Password

Create these items in the `homelab` vault:

### 1. Technitium DNS1 API
- Type: API Credential
- Field: `credential` (text)
- Value: Your DNS1 API token

### 2. Technitium DNS2 API
- Type: API Credential
- Field: `credential` (text)
- Value: Your DNS2 API token

### 3. Proxmox Terraform
- Type: API Credential
- Field: `credential` (text)
- Value: Your Proxmox API token secret

### 4. Homelab VM Default
- Type: Password
- Field: `password`
- Value: Your default VM/LXC password

### 5. Homelab Infrastructure SSH
- Type: SSH Key
- Field: `public key` (text)
- Value: Your SSH public key (ssh-ed25519 ...)

### 6. Technitium DHCP Failover
- Type: Password
- Field: `shared_secret` (password)
- Value: Shared secret for DHCP failover

## Testing

### Test Ansible Vault Sync
```bash
cd /mnt/d/cluster/monger-homelab
eval $(op signin)
bash scripts/sync_secrets_from_1password_v2.sh
ansible-vault view inventory/raclette/group_vars/vault.yml --vault-password-file ~/.vault_pass
```

### Test Terraform
```bash
cd /mnt/d/cluster/monger-homelab/terraform
eval $(op signin)
terraform init
terraform plan
```

### Test Ansible Playbooks
```bash
cd /mnt/d/cluster/monger-homelab
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_api_backup.yml \
  --vault-password-file ~/.vault_pass
```

## Security Improvements

✅ **No secrets in git** - All credentials removed from repository  
✅ **Single source of truth** - 1Password is authoritative  
✅ **Config-driven** - Easy to add new secrets via `secrets_mapping.yml`  
✅ **Encrypted at rest** - Ansible Vault uses AES256  
✅ **Terraform integration** - Direct 1Password provider access  
✅ **Audit trail** - 1Password tracks all access  

---

**Last Updated**: 2025-10-20  
**Status**: ✅ Complete - All hardcoded credentials migrated
