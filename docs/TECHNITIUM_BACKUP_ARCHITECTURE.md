# Technitium Backup Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Automation Host (WSL)                        │
│                    192.168.20.50 / localhost                     │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Ansible Playbook: technitium_daily_backup.yml         │    │
│  │  - Loads vault password                                 │    │
│  │  - Decrypts vault.yml                                   │    │
│  │  - Loads API tokens for each server                     │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                    │
│                              ▼                                    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Ansible Inventory & Variables                          │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │ vault.yml (encrypted)                            │  │    │
│  │  │ vault_technitium_tokens:                         │  │    │
│  │  │   technitium-dns1: "token1..."                   │  │    │
│  │  │   technitium-dns2: "token2..."                   │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │ group_vars/technitium_dns.yml                    │  │    │
│  │  │ - technitium_port: 5380                          │  │    │
│  │  │ - backup_retention_days: 30                      │  │    │
│  │  │ - unraid_backup_path: /mnt/unraid-backups/...   │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │ host_vars/technitium-dns1.yml                    │  │    │
│  │  │ technitium_api_token: "{{ vault_...['dns1'] }}"  │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │ host_vars/technitium-dns2.yml                    │  │    │
│  │  │ technitium_api_token: "{{ vault_...['dns2'] }}"  │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Unraid NFS Mount                                       │    │
│  │  /mnt/unraid-backups/technitium/                       │    │
│  │  - technitium-dns1-2025-01-20-1430.zip                 │    │
│  │  - technitium-dns2-2025-01-20-1430.zip                 │    │
│  │  - (auto-cleanup after 30 days)                        │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ API Calls (HTTP POST)
                              │ with token authentication
                              ▼
        ┌─────────────────────────────────────────┐
        │                                         │
        ▼                                         ▼
┌───────────────────┐                  ┌───────────────────┐
│ Technitium DNS 1  │                  │ Technitium DNS 2  │
│ 192.168.20.29     │                  │ 192.168.20.28     │
│                   │                  │                   │
│ ┌───────────────┐ │                  │ ┌───────────────┐ │
│ │ API Endpoint  │ │                  │ │ API Endpoint  │ │
│ │ :5380/api/    │ │                  │ │ :5380/api/    │ │
│ │ settings/     │ │                  │ │ settings/     │ │
│ │ backup        │ │                  │ │ backup        │ │
│ └───────────────┘ │                  │ └───────────────┘ │
│         │         │                  │         │         │
│         ▼         │                  │         ▼         │
│ ┌───────────────┐ │                  │ ┌───────────────┐ │
│ │ Creates .zip  │ │                  │ │ Creates .zip  │ │
│ │ in /tmp/      │ │                  │ │ in /tmp/      │ │
│ └───────────────┘ │                  │ └───────────────┘ │
│         │         │                  │         │         │
│         │ Ansible fetch module       │         │         │
│         └─────────┼──────────────────┼─────────┘         │
│                   │                  │                   │
└───────────────────┘                  └───────────────────┘
```

## Data Flow

### 1. Backup Initiation
```
Cron/Manual → Ansible Playbook → Load Vault → Decrypt Tokens
```

### 2. API Authentication
```
Playbook → HTTP POST with token → Technitium API → Validates token
```

### 3. Backup Creation
```
Technitium API → Creates backup.zip → Saves to /tmp/
```

### 4. Backup Transfer
```
Ansible fetch → Downloads from /tmp/ → Saves to Unraid NFS mount
```

### 5. Cleanup
```
Remove /tmp/*.zip on servers → Remove old backups on Unraid (>30 days)
```

## Variable Inheritance

```
vault.yml (encrypted)
    │
    └─> vault_technitium_tokens:
            technitium-dns1: "token1..."
            technitium-dns2: "token2..."
                │
                ├─> host_vars/technitium-dns1.yml
                │       technitium_api_token: "{{ vault_technitium_tokens['technitium-dns1'] }}"
                │
                └─> host_vars/technitium-dns2.yml
                        technitium_api_token: "{{ vault_technitium_tokens['technitium-dns2'] }}"
                                │
                                └─> Playbook tasks use: {{ technitium_api_token }}
```

## Security Layers

```
┌────────────────────────────────────────────────────────┐
│ Layer 1: Ansible Vault Encryption                      │
│ - vault.yml encrypted with AES256                      │
│ - Requires vault password to decrypt                   │
└────────────────────────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│ Layer 2: Variable Indirection                          │
│ - Tokens referenced via Jinja2 templates               │
│ - Never stored in plaintext in playbooks               │
└────────────────────────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│ Layer 3: API Token Authentication                      │
│ - Tokens validated by Technitium                       │
│ - Tokens can be rotated without changing playbooks     │
└────────────────────────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│ Layer 4: Network Security                              │
│ - API calls over private network (192.168.20.x)        │
│ - No external exposure                                 │
└────────────────────────────────────────────────────────┘
```

## Backup Lifecycle

```
┌─────────────┐
│   Create    │  Technitium API creates backup.zip
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Transfer   │  Ansible fetch downloads to Unraid
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Store     │  Saved to /mnt/unraid-backups/technitium/
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Retain    │  Kept for 30 days (configurable)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Cleanup   │  Automatically deleted after retention period
└─────────────┘
```

## Comparison: Old vs New

### Old Method (File-Based)
```
Ansible → SSH to server → docker cp /etc/dns → tar.gz → scp to Unraid
         (requires root)   (fragile)         (manual)   (slow)
```

### New Method (API-Based)
```
Ansible → HTTP POST with token → Technitium creates .zip → fetch to Unraid
         (no root needed)       (built-in feature)        (fast)
```

## API Endpoints Used

### Backup
```
POST http://192.168.20.29:5380/api/settings/backup
Body: token=YOUR_TOKEN
Response: backup.zip (binary file)
```

### Other Available Endpoints
```
GET  /api/zones/list?token=TOKEN          # List DNS zones
POST /api/zones/create                     # Create zone
POST /api/dhcp/scopes/set                  # Configure DHCP
GET  /api/settings/get?token=TOKEN         # Get settings
POST /api/settings/restore                 # Restore backup
```

## Automation Schedule

```
┌─────────────────────────────────────────────────────────────┐
│                    Daily at 2:00 AM                          │
│                                                               │
│  Cron Job                                                     │
│  ├─> Load vault password from ~/.vault_pass                  │
│  ├─> Run ansible-playbook                                    │
│  ├─> Backup technitium-dns1 (parallel)                       │
│  ├─> Backup technitium-dns2 (parallel)                       │
│  ├─> Cleanup old backups (>30 days)                          │
│  └─> Generate summary report                                 │
│                                                               │
│  Output: /tmp/technitium-backup.log                          │
└─────────────────────────────────────────────────────────────┘
```

## Disaster Recovery

### Scenario 1: Single Server Failure
```
1. Deploy new Technitium server
2. Get latest backup: /mnt/unraid-backups/technitium/technitium-dns1-*.zip
3. Restore via UI: Settings → Backup & Restore → Choose File
4. Verify configuration
```

### Scenario 2: Both Servers Failure
```
1. Deploy both new servers
2. Get latest backups for both
3. Restore each server independently
4. Verify DNS resolution
5. Verify DHCP scopes
```

### Scenario 3: Backup System Failure
```
1. Check Unraid mount: ls /mnt/unraid-backups/technitium/
2. Check cron: crontab -l
3. Check logs: tail /tmp/technitium-backup.log
4. Manual backup: ansible-playbook ... --ask-vault-pass
```

## Monitoring Points

```
┌────────────────────────────────────────────────────────┐
│ What to Monitor                                         │
├────────────────────────────────────────────────────────┤
│ ✓ Backup file creation (daily)                         │
│ ✓ Backup file size (should be consistent)              │
│ ✓ Unraid disk space (for backup storage)               │
│ ✓ Cron job execution (check logs)                      │
│ ✓ API token validity (test periodically)               │
│ ✓ Backup restoration (test quarterly)                  │
└────────────────────────────────────────────────────────┘
```

## File Locations Reference

```
monger-homelab/
├── inventory/raclette/
│   ├── group_vars/
│   │   ├── vault.yml                    # Encrypted tokens
│   │   └── technitium_dns.yml           # Group config
│   ├── host_vars/
│   │   ├── technitium-dns1.yml          # Server 1 token ref
│   │   └── technitium-dns2.yml          # Server 2 token ref
│   └── inventory.ini                     # Host definitions
├── playbook/
│   ├── technitium_daily_backup.yml      # Main backup playbook
│   ├── technitium_api_backup.yml        # Alternative (same)
│   ├── technitium_daily_backup_old.yml  # Old method (deprecated)
│   ├── configure_dhcp_api.yml           # DHCP config (uses tokens)
│   ├── configure_dns_zones.yml          # DNS config (uses tokens)
│   ├── README_TECHNITIUM_BACKUP_REFACTOR.md
│   ├── README_TECHNITIUM_API_SETUP.md
│   └── QUICKSTART_BACKUP.md
├── scripts/
│   └── add_technitium_tokens_to_vault.sh
└── REFACTOR_SUMMARY.md
```

## Network Topology

```
                    Internet
                        │
                        ▼
                  ┌──────────┐
                  │  Router  │
                  └────┬─────┘
                       │
        ┌──────────────┼──────────────┐
        │         192.168.20.0/24      │
        │                              │
        ▼                              ▼
┌───────────────┐            ┌───────────────┐
│ Technitium 1  │            │ Technitium 2  │
│ .29           │◄──────────►│ .28           │
└───────┬───────┘  Failover  └───────┬───────┘
        │                            │
        │                            │
        └────────────┬───────────────┘
                     │
                     ▼
            ┌────────────────┐
            │ Automation Host│
            │ .50            │
            └────────┬───────┘
                     │
                     ▼
            ┌────────────────┐
            │ Unraid NAS     │
            │ .5             │
            │ /backups/      │
            └────────────────┘
```

## Success Metrics

```
┌────────────────────────────────────────────────────────┐
│ Metric                    │ Target      │ Status       │
├───────────────────────────┼─────────────┼──────────────┤
│ Backup Success Rate       │ 100%        │ TBD          │
│ Backup Duration           │ < 5 min     │ TBD          │
│ Backup Size               │ ~10-50 MB   │ TBD          │
│ Token Rotation Frequency  │ 90 days     │ TBD          │
│ Restore Success Rate      │ 100%        │ TBD          │
│ Restore Duration          │ < 2 min     │ TBD          │
└────────────────────────────────────────────────────────┘
```
