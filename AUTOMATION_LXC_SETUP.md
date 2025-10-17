# Automation LXC Container Setup

## Quick Start

Deploy and configure the automation LXC container in 5 steps.

---

## Step 1: Deploy LXC Container

```bash
cd /mnt/d/cluster/monger-homelab/terraform

# Deploy the automation LXC
terraform apply -target=proxmox_lxc.automation

# Wait for container to start (about 30 seconds)
```

## Step 1b: Enable NFS Mount Capability

```bash
cd /mnt/d/cluster/monger-homelab

# Run the setup script to enable NFS mounts
bash scripts/setup_lxc_nfs.sh

# This will:
# - Stop the container
# - Add mount=nfs feature
# - Restart the container
```

**Note:** This step is required because the Terraform API token doesn't have permission to set mount features.

**What this creates:**
- LXC container on pve1
- Hostname: `automation`
- IP: `192.168.20.50`
- Resources: 1 CPU, 512MB RAM, 8GB disk
- OS: Ubuntu 22.04

---

## Step 2: Create Admin User (Initial Bootstrap)

```bash
cd /mnt/d/cluster/monger-homelab

# Temporarily use root for initial setup
# Edit inventory to use root
sed -i 's/ansible_user=james/ansible_user=root/' inventory/raclette/inventory.ini

# Create james user and setup SSH
ansible-playbook -i inventory/raclette/inventory.ini playbook/bootstrap_automation_initial.yml

# Restore inventory to use james
sed -i 's/ansible_user=root/ansible_user=james/' inventory/raclette/inventory.ini

# Verify you can SSH as james
ssh james@192.168.20.50
exit
```

## Step 3: Full Bootstrap

```bash
# Now run the full bootstrap as james user
ansible-playbook -i inventory/raclette/inventory.ini playbook/bootstrap_automation_lxc.yml

# This will:
# - Install Ansible, Git, Python
# - Clone your repo
# - Setup NFS mount to Unraid
# - Configure cron jobs
# - Generate SSH keys
```

**Note:** The playbook will display the SSH public key at the end. Copy it for the next step.

---

## Step 3: Setup SSH Keys

The automation container needs SSH access to managed nodes (dns1, dns2).

```bash
# SSH to automation container
ssh root@192.168.20.50

# Switch to automation user
su - automation

# Copy SSH key to managed nodes
ssh-copy-id james@192.168.20.29  # dns1
ssh-copy-id james@192.168.20.28  # dns2

# Test connectivity
ssh james@192.168.20.29 "hostname"
ssh james@192.168.20.28 "hostname"
```

---

## Step 4: Test Ansible

```bash
# Still on automation container as automation user
cd /opt/automation/monger-homelab

# Test Ansible connectivity
ansible -i inventory/raclette/inventory.ini technitium_dns -m ping

# Expected output:
# technitium-dns1 | SUCCESS => { "ping": "pong" }
# technitium-dns2 | SUCCESS => { "ping": "pong" }
```

---

## Step 5: Test Manual Backup

```bash
# Run a test backup
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml

# Check if backups were created
ls -lh /mnt/unraid-backups/technitium/

# Expected: Two backup files (one for each DNS server)
# technitium-dns1-2025-10-17-1145.tar.gz
# technitium-dns2-2025-10-17-1145.tar.gz
```

---

## Verification

### Check Cron Jobs

```bash
ssh root@192.168.20.50

# View cron jobs
crontab -l

# Expected:
# 0 2 * * * cd /opt/automation/monger-homelab && /usr/bin/ansible-playbook ...
# 0 1 * * * cd /opt/automation/monger-homelab && /usr/bin/git pull ...
```

### Check Logs

```bash
# View backup log
tail -f /var/log/dns-backup.log

# View git pull log
tail -f /var/log/git-pull.log
```

### Check Mounts

```bash
# Verify Unraid is mounted
mount | grep unraid

# Expected:
# 192.168.20.5:/mnt/user/backups on /mnt/unraid-backups type nfs ...
```

---

## Scheduled Jobs

The automation container runs these jobs automatically:

| Job | Schedule | Description |
|-----|----------|-------------|
| **Git Pull** | 1:00 AM daily | Pull latest configs from Git |
| **DNS Backup** | 2:00 AM daily | Backup all DNS servers to Unraid |

---

## Manual Operations

### Run Backup Manually

```bash
ssh automation@192.168.20.50
cd /opt/automation/monger-homelab
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml
```

### Deploy DNS Changes

```bash
ssh automation@192.168.20.50
cd /opt/automation/monger-homelab

# Pull latest
git pull

# Generate zones
python3 scripts/generate_dns_zones.py

# Deploy
ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_dns_zones.yml
```

### Deploy DHCP Changes

```bash
ssh automation@192.168.20.50
cd /opt/automation/monger-homelab

# Pull latest
git pull

# Deploy
ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_dhcp_api.yml
```

---

## Monitoring

### Check Backup Status

```bash
# From your desktop
ssh automation@192.168.20.50 "ls -lht /mnt/unraid-backups/technitium/ | head -10"

# Or use the status script
ssh automation@192.168.20.50 "cd /opt/automation/monger-homelab && bash scripts/check_backup_status.sh"
```

### View Recent Logs

```bash
# Backup logs
ssh automation@192.168.20.50 "tail -50 /var/log/dns-backup.log"

# Git pull logs
ssh automation@192.168.20.50 "tail -50 /var/log/git-pull.log"
```

---

## Troubleshooting

### Container won't start

```bash
# Check container status in Proxmox
ssh root@192.168.20.100
pct list
pct status 100  # Replace with your container ID

# Start manually
pct start 100
```

### Can't SSH to container

```bash
# Check if container is running
ssh root@192.168.20.100
pct list | grep automation

# Try from Proxmox host
ssh root@192.168.20.100
pct enter 100  # Replace with your container ID
```

### Ansible can't connect to DNS servers

```bash
ssh automation@192.168.20.50
su - automation

# Test SSH manually
ssh james@192.168.20.29

# If fails, copy SSH key again
ssh-copy-id james@192.168.20.29
```

### Unraid mount fails

```bash
ssh root@192.168.20.50

# Check if Unraid is accessible
ping 192.168.20.5

# Check NFS export on Unraid
# Unraid Web UI → Shares → backups → Enable NFS export

# Try mounting manually
mount -t nfs 192.168.20.5:/mnt/user/backups /mnt/unraid-backups
```

### Backups not running

```bash
# Check cron service
ssh root@192.168.20.50
systemctl status cron

# Check cron logs
grep CRON /var/log/syslog | tail -20

# Run backup manually to see errors
su - automation
cd /opt/automation/monger-homelab
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml -vvv
```

---

## Maintenance

### Update Repository

```bash
ssh automation@192.168.20.50
su - automation
cd /opt/automation/monger-homelab
git pull
```

### Update Ansible

```bash
ssh root@192.168.20.50
apt update
apt upgrade ansible
```

### Backup the Container

```bash
# From Proxmox host
ssh root@192.168.20.100

# Backup container
vzdump 100 --compress gzip --mode snapshot --storage local

# Backups stored in: /var/lib/vz/dump/
```

---

## Container Management

### Start/Stop Container

```bash
# From Proxmox host
ssh root@192.168.20.100

# Stop
pct stop 100

# Start
pct start 100

# Restart
pct restart 100
```

### Access Console

```bash
# From Proxmox host
pct enter 100

# Or via Proxmox Web UI
# Select container → Console
```

### Resource Usage

```bash
# Check resource usage
ssh automation@192.168.20.50
htop

# Or from Proxmox
pct status 100 --verbose
```

---

## Next Steps

Once automation is working:

1. ✅ **Verify backups** - Check tomorrow that backups ran
2. ✅ **Test restore** - Practice restoring from backup
3. ✅ **Monitor logs** - Check logs weekly
4. 📋 **Add monitoring** - Setup alerts (optional)
5. 📋 **Deploy n8n** - Visual workflows (future)

---

## Quick Reference

```bash
# SSH to container
ssh automation@192.168.20.50

# View cron jobs
crontab -l

# View logs
tail -f /var/log/dns-backup.log

# List backups
ls -lh /mnt/unraid-backups/technitium/

# Test Ansible
ansible -i inventory/raclette/inventory.ini all -m ping

# Manual backup
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml
```

---

## Files Reference

- `terraform/automation-lxc.tf` - LXC definition
- `playbook/bootstrap_automation_lxc.yml` - Bootstrap playbook
- `inventory/raclette/inventory.ini` - Inventory (automation group)
- `AUTOMATION_STRATEGY.md` - Long-term automation plan

---

**Your automation is now running!** 🎉

Backups will run automatically every night at 2 AM.
