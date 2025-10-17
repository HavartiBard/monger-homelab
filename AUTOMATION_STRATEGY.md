# Automation Strategy

## Overview

We have multiple options for running periodic automation tasks (backups, DNS updates, etc.):

1. **Cron in LXC** - Traditional, simple, reliable
2. **n8n Workflows** - Visual, powerful, modern ⭐ Recommended for future

---

## Current Plan: Hybrid Approach

### Phase 1: LXC with Cron (Now)
**Quick setup for immediate automation needs**

- ✅ Simple and reliable
- ✅ Traditional cron jobs
- ✅ Lightweight (512MB RAM)
- ✅ Easy to backup/restore
- ✅ Gets automation working today

### Phase 2: n8n Integration (Later)
**Migrate to n8n for better management**

- ✅ Visual workflow editor
- ✅ Built-in scheduling
- ✅ Error handling & retries
- ✅ Notifications (Slack, email, etc.)
- ✅ Webhook triggers
- ✅ Easy to modify without SSH

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Proxmox Cluster                     │
│                                                     │
│  ┌──────────────────┐      ┌──────────────────┐   │
│  │  Automation LXC  │      │    n8n LXC       │   │
│  │  (Phase 1)       │──────│   (Phase 2)      │   │
│  │                  │      │                  │   │
│  │  - Cron jobs     │      │  - Workflows     │   │
│  │  - Ansible       │      │  - Scheduling    │   │
│  │  - Git repo      │      │  - Notifications │   │
│  │  192.168.20.50   │      │  192.168.20.51   │   │
│  └──────────────────┘      └──────────────────┘   │
│           │                         │              │
│           └─────────┬───────────────┘              │
│                     │                              │
│         ┌───────────▼──────────┐                   │
│         │  Managed Services    │                   │
│         │  - DNS servers       │                   │
│         │  - DHCP servers      │                   │
│         │  - Unraid backups    │                   │
│         └──────────────────────┘                   │
└─────────────────────────────────────────────────────┘
```

---

## Phase 1: Automation LXC (Immediate)

### Deploy

```bash
cd terraform

# Deploy LXC container
terraform apply -target=proxmox_lxc.automation

# Bootstrap with Ansible
ansible-playbook -i inventory/raclette/inventory.ini playbook/bootstrap_automation_lxc.yml
```

### What It Does

- **Daily DNS Backups** (2 AM)
- **Git sync** (pulls latest configs)
- **DNS zone deployment** (if configs changed)
- **DHCP updates** (if configs changed)

### Files

- `terraform/automation-lxc.tf` - LXC definition
- `playbook/bootstrap_automation_lxc.yml` - Setup playbook
- Cron jobs configured automatically

---

## Phase 2: n8n Workflows (Future)

### Why n8n?

1. **Visual Workflows** - Drag-and-drop automation
2. **Built-in Scheduling** - Better than cron
3. **Error Handling** - Automatic retries
4. **Notifications** - Slack, email, webhooks
5. **Monitoring** - See execution history
6. **Easy Updates** - No SSH needed

### n8n Use Cases

#### Workflow 1: DNS Backup & Monitoring
```
Schedule (Daily 2 AM)
  ↓
Execute Ansible Playbook (SSH)
  ↓
Check Backup Success
  ↓
If Failed → Send Slack Alert
  ↓
If Success → Update Status Dashboard
```

#### Workflow 2: Git-Driven DNS Updates
```
Webhook (GitHub Push)
  ↓
Pull Latest Configs
  ↓
Generate DNS Zones (Python)
  ↓
Deploy via Ansible
  ↓
Notify Slack with Changes
```

#### Workflow 3: Cloudflare Sync
```
Schedule (Hourly)
  ↓
Check for DNS Changes
  ↓
If Changed → Sync to Cloudflare
  ↓
Notify on Success/Failure
```

#### Workflow 4: Health Monitoring
```
Schedule (Every 5 min)
  ↓
Check DNS Resolution
  ↓
Check DHCP Leases
  ↓
Check Backup Age
  ↓
If Issues → Alert
```

### n8n Setup (Future)

```bash
# Deploy n8n LXC
cd terraform
terraform apply -target=proxmox_lxc.n8n

# Access n8n
# http://192.168.20.51:5678
```

### n8n Workflows to Create

1. **dns-backup-workflow.json** - Daily backups
2. **dns-deploy-workflow.json** - Git-driven updates
3. **cloudflare-sync-workflow.json** - Public DNS sync
4. **health-check-workflow.json** - Monitoring
5. **cert-renewal-workflow.json** - SSL certificate management

---

## Comparison

| Feature | Cron (Phase 1) | n8n (Phase 2) |
|---------|----------------|---------------|
| **Setup Time** | 15 minutes | 1-2 hours |
| **Ease of Use** | SSH + crontab | Web UI |
| **Scheduling** | Basic cron | Advanced |
| **Error Handling** | Manual | Built-in |
| **Notifications** | Email only | Slack, Discord, etc. |
| **Monitoring** | Log files | Dashboard |
| **Modifications** | SSH + edit | Web UI |
| **Complexity** | Simple | More features |
| **Resource Usage** | 512MB RAM | 1GB RAM |

---

## Migration Path

### Step 1: Start with Cron (Now)
```bash
# Deploy automation LXC
terraform apply -target=proxmox_lxc.automation

# Bootstrap
ansible-playbook playbook/bootstrap_automation_lxc.yml

# Verify backups work
ssh automation@192.168.20.50
sudo crontab -l
```

### Step 2: Add n8n (Later)
```bash
# Deploy n8n LXC
terraform apply -target=proxmox_lxc.n8n

# Setup n8n
# Import workflows
# Test workflows

# Run both in parallel for validation
```

### Step 3: Migrate to n8n (When Ready)
```bash
# Disable cron jobs
ssh automation@192.168.20.50
sudo crontab -e  # Comment out jobs

# Verify n8n workflows running
# Monitor for a week

# Decommission automation LXC if desired
```

---

## Recommended Timeline

### Week 1: Get Automation Working
- ✅ Deploy automation LXC
- ✅ Setup cron jobs
- ✅ Verify backups running
- ✅ Test restore procedure

### Month 1-2: Stabilize
- ✅ Monitor backup success
- ✅ Tune schedules
- ✅ Add monitoring alerts

### Month 3+: Enhance with n8n
- 📋 Deploy n8n LXC
- 📋 Create workflows
- 📋 Add Slack notifications
- 📋 Build monitoring dashboard
- 📋 Migrate from cron

---

## n8n Workflow Examples

### DNS Backup Workflow (n8n)

```json
{
  "name": "DNS Daily Backup",
  "nodes": [
    {
      "type": "n8n-nodes-base.schedule",
      "name": "Daily at 2 AM",
      "parameters": {
        "rule": {
          "interval": [{"field": "hours", "hoursInterval": 24}]
        }
      }
    },
    {
      "type": "n8n-nodes-base.ssh",
      "name": "Run Ansible Backup",
      "parameters": {
        "command": "cd /opt/automation/monger-homelab && ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml"
      }
    },
    {
      "type": "n8n-nodes-base.if",
      "name": "Check Success",
      "parameters": {
        "conditions": {
          "string": [
            {"value1": "{{$json.exitCode}}", "value2": "0"}
          ]
        }
      }
    },
    {
      "type": "n8n-nodes-base.slack",
      "name": "Notify Success",
      "parameters": {
        "message": "✅ DNS backup completed successfully"
      }
    },
    {
      "type": "n8n-nodes-base.slack",
      "name": "Alert Failure",
      "parameters": {
        "message": "❌ DNS backup FAILED! Check logs."
      }
    }
  ]
}
```

---

## Resources

### Documentation
- `AUTOMATION_SERVER_SETUP.md` - LXC setup guide
- `terraform/automation-lxc.tf` - LXC definition
- `playbook/bootstrap_automation_lxc.yml` - Bootstrap playbook

### Future n8n Resources
- n8n Documentation: https://docs.n8n.io
- n8n Community Workflows: https://n8n.io/workflows
- Ansible n8n Node: https://www.npmjs.com/package/n8n-nodes-ansible

---

## Decision: Start with Cron, Migrate to n8n

**Recommendation:** 
1. ✅ Deploy automation LXC with cron **now** (15 min setup)
2. ✅ Get backups working reliably
3. 📋 Deploy n8n **later** when you have time (weekend project)
4. 📋 Migrate workflows gradually

This gives you:
- ✅ **Immediate automation** (backups running tonight)
- ✅ **Future flexibility** (n8n when ready)
- ✅ **No rush** (migrate at your pace)
- ✅ **Learning opportunity** (explore n8n features)

---

## Next Steps

### Today: Deploy Automation LXC
```bash
cd /mnt/d/cluster/monger-homelab/terraform
terraform apply -target=proxmox_lxc.automation
```

### This Week: Verify Backups
```bash
# Check backups are running
ssh automation@192.168.20.50
sudo tail -f /var/log/dns-backup.log
```

### Later: Explore n8n
- Read n8n documentation
- Plan workflows
- Deploy when ready

🎯 **Start simple, enhance later!**
