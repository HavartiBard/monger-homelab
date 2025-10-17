# Cloudflare DNS Sync

## Overview

Records in the root domain (`klsll.com`) can be automatically synced to Cloudflare for external DNS resolution.

## Marking Records for Cloudflare

Add `[CLOUDFLARE]` as the 5th field to any record you want synced:

```
ZONE: klsll.com

# This record will be synced to Cloudflare
unraid,A,192.168.20.5,3600,[CLOUDFLARE]

# This record stays local only
internal-server,A,192.168.20.50,3600

ENDZONE
```

## Setup

### 1. Get Cloudflare Credentials

1. Log into Cloudflare dashboard
2. Go to **My Profile** → **API Tokens**
3. Create token with **Zone.DNS** edit permissions
4. Get your Zone ID from the domain overview page

### 2. Set Environment Variables

```bash
export CLOUDFLARE_API_TOKEN="your-api-token-here"
export CLOUDFLARE_ZONE_ID="your-zone-id-here"
```

### 3. Install Cloudflare Library

```bash
pip3 install cloudflare
```

## Workflow

### Generate and Sync

```bash
# 1. Edit records
vim config/dns_records_manual.conf

# 2. Generate zones (also exports Cloudflare records)
python3 scripts/generate_dns_zones.py

# 3. Review what will be synced
cat config/dns_records_cloudflare.json

# 4. Sync to Cloudflare
python3 scripts/sync_to_cloudflare.py

# 5. Deploy to local DNS servers
ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_dns_zones.yml
```

## Use Cases

### Public Services

For services you want accessible from the internet:

```
ZONE: klsll.com

# Public-facing services (use Cloudflare Tunnel for secure access)
unraid,A,192.168.20.5,3600,[CLOUDFLARE]
plex,CNAME,unraid.klsll.com.,3600,[CLOUDFLARE]

ENDZONE
```

### Split-Horizon DNS

Same hostname, different IPs for internal vs external:

**Internal (Technitium):**
```
ZONE: klsll.com
unraid,A,192.168.20.5,3600
ENDZONE
```

**External (Cloudflare):**
```
ZONE: klsll.com
unraid,A,<public-ip>,3600,[CLOUDFLARE]
ENDZONE
```

Internal clients get the private IP, external clients get the public IP.

## Cloudflare Tunnel Integration

For secure external access without exposing ports:

1. **Set up Cloudflare Tunnel** on your server
2. **Create DNS record** in Cloudflare pointing to the tunnel
3. **Mark for sync** in your config:
   ```
   service,CNAME,tunnel-id.cfargotunnel.com.,3600,[CLOUDFLARE]
   ```

## Security Notes

⚠️ **Do NOT** sync internal IPs to Cloudflare unless using Cloudflare Tunnel  
⚠️ **Do NOT** commit API tokens to Git  
✅ **Use** Cloudflare Tunnel for secure external access  
✅ **Use** split-horizon DNS for different internal/external IPs  

## Automation

### Git Hook (Optional)

Auto-sync on commit:

```bash
# .git/hooks/post-commit
#!/bin/bash
if git diff --name-only HEAD~1 | grep -q "config/dns_records_manual.conf"; then
    python3 scripts/generate_dns_zones.py
    python3 scripts/sync_to_cloudflare.py
fi
```

### Cron Job (Optional)

Sync every hour:

```bash
0 * * * * cd /path/to/repo && python3 scripts/sync_to_cloudflare.py
```

## Troubleshooting

### API Token Issues

```bash
# Test your token
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

### Zone ID Issues

```bash
# List your zones
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

### Records Not Syncing

1. Check `config/dns_records_cloudflare.json` was generated
2. Verify `[CLOUDFLARE]` marker is present
3. Check API token has DNS edit permissions
4. Verify Zone ID is correct

## Example Configuration

```
ZONE: klsll.com

# Services accessible externally via Cloudflare Tunnel
unraid,CNAME,tunnel-abc123.cfargotunnel.com.,3600,[CLOUDFLARE]
plex,CNAME,tunnel-abc123.cfargotunnel.com.,3600,[CLOUDFLARE]

# Services with public IPs
vpn,A,203.0.113.10,3600,[CLOUDFLARE]

# Internal-only (no Cloudflare marker)
internal-api,A,192.168.20.50,3600

ENDZONE
```
