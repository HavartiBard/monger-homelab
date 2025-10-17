# Automation Server Setup

## Recommended: Run on Proxmox Host

For homelab reliability, run Ansible automation directly on a Proxmox host.

---

## Setup on Proxmox Host (pve1)

### 1. Install Ansible

```bash
# SSH to pve1
ssh root@192.168.20.100

# Install Ansible
apt update
apt install -y ansible git python3-pip python3-venv

# Verify
ansible --version
```

### 2. Clone Repository

```bash
# Create automation directory
mkdir -p /opt/automation
cd /opt/automation

# Clone your repo (use SSH key or HTTPS)
git clone git@github.com:yourusername/monger-homelab.git
# OR
git clone https://github.com/yourusername/monger-homelab.git

cd monger-homelab
```

### 3. Setup SSH Keys

```bash
# Generate SSH key for Ansible (if not exists)
ssh-keygen -t ed25519 -C "ansible@pve1" -f /root/.ssh/id_ed25519 -N ""

# Copy to managed nodes
ssh-copy-id james@192.168.20.29  # dns1
ssh-copy-id james@192.168.20.28  # dns2

# Test connectivity
ansible -i inventory/raclette/inventory.ini all -m ping
```

### 4. Setup Unraid NFS Mount

```bash
# Install NFS client
apt install -y nfs-common

# Create mount point
mkdir -p /mnt/unraid-backups

# Add to /etc/fstab
echo "192.168.20.5:/mnt/user/backups /mnt/unraid-backups nfs defaults 0 0" >> /etc/fstab

# Mount
mount -a

# Verify
df -h /mnt/unraid-backups
```

### 5. Test Manual Backup

```bash
cd /opt/automation/monger-homelab

# Run manual backup
ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml

# Verify backups created
ls -lh /mnt/unraid-backups/technitium/
```

### 6. Setup Cron Jobs

```bash
# Edit root crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /opt/automation/monger-homelab && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml >> /var/log/dns-backup.log 2>&1

# Optional: Pull latest config from Git before backup (if you update configs)
0 1 * * * cd /opt/automation/monger-homelab && git pull >> /var/log/git-pull.log 2>&1

# Optional: Deploy DNS/DHCP changes automatically (if configs changed)
30 1 * * * cd /opt/automation/monger-homelab && git pull && python3 scripts/generate_dns_zones.py && ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_dns_zones.yml >> /var/log/dns-deploy.log 2>&1
```

### 7. Setup Log Rotation

```bash
# Create logrotate config
cat > /etc/logrotate.d/ansible-automation << 'EOF'
/var/log/dns-backup.log
/var/log/dns-deploy.log
/var/log/git-pull.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
EOF
```

### 8. Verify Setup

```bash
# Check cron jobs
crontab -l

# Check mount
mount | grep unraid

# Test Ansible connectivity
cd /opt/automation/monger-homelab
ansible -i inventory/raclette/inventory.ini all -m ping

# Check logs
tail -f /var/log/dns-backup.log
```

---

## Alternative: Dedicated VM

If you prefer a separate VM:

### 1. Deploy via Terraform

```bash
# Edit terraform/automation-server.tf
# Change: count = 0
# To: count = 1

cd terraform
terraform apply
```

### 2. Bootstrap the VM

```bash
# SSH to new VM
ssh ansible@192.168.20.50

# Install Ansible
sudo apt update
sudo apt install -y ansible git python3-pip

# Clone repo
git clone https://github.com/yourusername/monger-homelab.git
cd monger-homelab

# Setup SSH keys and follow steps 3-8 above
```

---

## Alternative: Docker on Unraid

### 1. Create Docker Compose

```yaml
# /mnt/user/appdata/ansible/docker-compose.yml
version: '3'
services:
  ansible-cron:
    image: cytopia/ansible:latest
    container_name: ansible-automation
    volumes:
      - /mnt/user/appdata/ansible/repo:/ansible
      - /mnt/user/backups/technitium:/backups
      - /root/.ssh:/root/.ssh:ro
    environment:
      - TZ=America/Los_Angeles
    command: |
      sh -c "
        cd /ansible &&
        while true; do
          # Run at 2 AM
          if [ $(date +%H:%M) = '02:00' ]; then
            ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml
            sleep 3600
          fi
          sleep 60
        done
      "
    restart: unless-stopped
```

### 2. Start Container

```bash
cd /mnt/user/appdata/ansible
docker-compose up -d
```

---

## Comparison

| Method | Pros | Cons | Recommended For |
|--------|------|------|-----------------|
| **Proxmox Host** | Always on, no extra VM, simple | Runs as root, less isolated | **Homelab** ✅ |
| **Dedicated VM** | Isolated, dedicated resources | Extra VM to maintain | Production |
| **Docker on Unraid** | Containerized, easy to manage | Requires Docker knowledge | Docker-heavy setups |
| **Desktop/WSL** | Easy development | Not reliable for automation | Development only |

---

## Monitoring

### Check Backup Status

```bash
# On automation server
cd /opt/automation/monger-homelab
bash scripts/check_backup_status.sh
```

### View Logs

```bash
# Backup logs
tail -f /var/log/dns-backup.log

# Cron logs
grep CRON /var/log/syslog | tail -20
```

### Email Alerts (Optional)

```bash
# Install mail utilities
apt install -y mailutils

# Update cron to send email on failure
0 2 * * * cd /opt/automation/monger-homelab && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml >> /var/log/dns-backup.log 2>&1 || echo "Backup failed!" | mail -s "DNS Backup Alert" you@example.com
```

---

## Security Considerations

### SSH Key Management

```bash
# Use dedicated SSH key for automation
ssh-keygen -t ed25519 -C "automation@homelab" -f /root/.ssh/automation_key

# Add to managed nodes
ssh-copy-id -i /root/.ssh/automation_key james@192.168.20.29

# Update ansible.cfg to use specific key
[defaults]
private_key_file = /root/.ssh/automation_key
```

### Restrict Ansible User

On managed nodes (dns1, dns2):

```bash
# Create dedicated ansible user
sudo useradd -m -s /bin/bash ansible

# Allow passwordless sudo for specific commands only
echo "ansible ALL=(ALL) NOPASSWD: /usr/bin/docker, /bin/systemctl" | sudo tee /etc/sudoers.d/ansible
```

---

## Troubleshooting

### Cron not running

```bash
# Check cron service
systemctl status cron

# Check cron logs
grep CRON /var/log/syslog

# Test cron job manually
cd /opt/automation/monger-homelab && ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml
```

### Mount issues

```bash
# Check NFS mount
mount | grep unraid

# Remount
umount /mnt/unraid-backups
mount -a

# Check Unraid NFS export
# Unraid Web UI → Shares → backups → Enable NFS export
```

### Ansible connectivity

```bash
# Test SSH
ssh james@192.168.20.29

# Test Ansible
ansible -i inventory/raclette/inventory.ini all -m ping -vvv
```

---

## Recommendation

**For your homelab, use Proxmox host (pve1):**

1. ✅ Simple and reliable
2. ✅ No extra resources needed
3. ✅ Always available
4. ✅ Can manage entire infrastructure

Just follow the "Setup on Proxmox Host" section above! 🎯
