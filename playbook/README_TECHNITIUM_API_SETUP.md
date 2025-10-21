# Technitium API Token Setup

## Overview
This guide explains how to add Technitium API tokens to the Ansible vault for secure credential management.

## Current Status
The API tokens for both Technitium servers are currently hardcoded in:
- `playbook/configure_dhcp_api.yml`
- `playbook/configure_dns_zones.yml`

**Tokens:**
- `technitium-dns1`: `f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8`
- `technitium-dns2`: `819048ea9356f23157ab915dc4e8f9e2927ccaa206a207f61982c41da8842615`

## Adding Tokens to Vault

### Step 1: Edit the Vault
```bash
cd /mnt/d/cluster/monger-homelab
ansible-vault edit inventory/raclette/group_vars/vault.yml
```

### Step 2: Add Technitium Variables
Add these lines to the vault file:

```yaml
# Technitium DNS API Tokens
vault_technitium_tokens:
  technitium-dns1: "f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8"
  technitium-dns2: "819048ea9356f23157ab915dc4e8f9e2927ccaa206a207f61982c41da8842615"
```

### Step 3: Create Group Variables File
Create `inventory/raclette/group_vars/technitium_dns.yml`:

```yaml
---
# Technitium DNS Server Configuration
technitium_port: 5380

# API tokens (loaded from vault)
technitium_tokens: "{{ vault_technitium_tokens }}"
```

## Using Tokens in Playbooks

### Method 1: Direct Access (Current)
```yaml
vars:
  technitium_tokens:
    technitium-dns1: "{{ vault_technitium_tokens['technitium-dns1'] }}"
    technitium-dns2: "{{ vault_technitium_tokens['technitium-dns2'] }}"

tasks:
  - name: Set API token for this server
    set_fact:
      api_token: "{{ technitium_tokens[inventory_hostname] }}"
```

### Method 2: Host Variables (Recommended)
Create host-specific variables in `inventory/raclette/host_vars/`:

**host_vars/technitium-dns1.yml:**
```yaml
---
technitium_api_token: "{{ vault_technitium_tokens['technitium-dns1'] }}"
```

**host_vars/technitium-dns2.yml:**
```yaml
---
technitium_api_token: "{{ vault_technitium_tokens['technitium-dns2'] }}"
```

Then in playbooks:
```yaml
tasks:
  - name: Use API token directly
    uri:
      url: "http://{{ ansible_host }}:{{ technitium_port }}/api/settings/backup"
      method: GET
      body_format: form-urlencoded
      body:
        token: "{{ technitium_api_token }}"
```

## Technitium API Endpoints

### Backup API
```bash
# Create backup (returns .zip file)
GET http://server:5380/api/settings/backup?token=YOUR_TOKEN

# Or using form data
POST http://server:5380/api/settings/backup
Body: token=YOUR_TOKEN
```

### Restore API
```bash
# Restore from backup
POST http://server:5380/api/settings/restore
Body: 
  token=YOUR_TOKEN
  file=@backup.zip
```

### Other Useful Endpoints
```bash
# List zones
GET http://server:5380/api/zones/list?token=YOUR_TOKEN

# Get settings
GET http://server:5380/api/settings/get?token=YOUR_TOKEN

# Create DHCP scope
POST http://server:5380/api/dhcp/scopes/set
Body: token=YOUR_TOKEN&name=scope1&...
```

## Security Best Practices

1. **Never commit unencrypted tokens** to git
2. **Use ansible-vault** for all sensitive data
3. **Rotate tokens periodically** (generate new ones in Technitium UI)
4. **Limit token permissions** if Technitium supports it
5. **Use different tokens** for different automation tasks if possible

## Generating New API Tokens

1. Log into Technitium web UI: `http://server:5380`
2. Go to **Settings** → **API**
3. Click **Generate Token**
4. Copy the token and add it to the vault
5. Update playbooks to use the new token

## Testing Token Access

```bash
# Test backup endpoint
curl -X GET "http://192.168.20.29:5380/api/settings/backup?token=YOUR_TOKEN" \
  -o test-backup.zip

# Test zones list
curl -X GET "http://192.168.20.29:5380/api/zones/list?token=YOUR_TOKEN"
```

## Migration Checklist

- [ ] Add tokens to vault
- [ ] Create group_vars/technitium_dns.yml
- [ ] Create host_vars for each server
- [ ] Update configure_dhcp_api.yml to use vault
- [ ] Update configure_dns_zones.yml to use vault
- [ ] Update technitium_api_backup.yml to use vault
- [ ] Test all playbooks
- [ ] Remove hardcoded tokens from playbooks
