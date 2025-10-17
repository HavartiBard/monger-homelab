#!/bin/bash
# Enable automated daily backups for Technitium DNS servers

set -e

echo "========================================="
echo "Technitium DNS - Enable Daily Backups"
echo "========================================="
echo ""

# Configuration
REPO_DIR="/mnt/d/cluster/monger-homelab"
BACKUP_MOUNT="/mnt/unraid-backups"
UNRAID_IP="192.168.20.5"
UNRAID_SHARE="backups"
BACKUP_TIME="02:00"  # 2 AM

# Check if running in WSL
if ! grep -qi microsoft /proc/version; then
    echo "Error: This script must be run in WSL"
    exit 1
fi

echo "Step 1: Setup Unraid NFS Mount"
echo "================================"
echo ""

# Check if mount point exists
if [ ! -d "$BACKUP_MOUNT" ]; then
    echo "Creating mount point: $BACKUP_MOUNT"
    sudo mkdir -p "$BACKUP_MOUNT"
fi

# Check if already mounted
if mount | grep -q "$BACKUP_MOUNT"; then
    echo "✅ Unraid already mounted at $BACKUP_MOUNT"
else
    echo "Setting up NFS mount..."
    
    # Install NFS client if needed
    if ! command -v mount.nfs &> /dev/null; then
        echo "Installing nfs-common..."
        sudo apt update
        sudo apt install -y nfs-common
    fi
    
    # Add to fstab if not already there
    if ! grep -q "$BACKUP_MOUNT" /etc/fstab; then
        echo "Adding to /etc/fstab..."
        echo "$UNRAID_IP:/mnt/user/$UNRAID_SHARE $BACKUP_MOUNT nfs defaults 0 0" | sudo tee -a /etc/fstab
    fi
    
    # Mount now
    echo "Mounting Unraid share..."
    sudo mount -a
    
    if mount | grep -q "$BACKUP_MOUNT"; then
        echo "✅ Successfully mounted Unraid"
    else
        echo "❌ Failed to mount Unraid"
        echo "Please check:"
        echo "  1. Unraid is accessible at $UNRAID_IP"
        echo "  2. NFS export is enabled in Unraid"
        echo "  3. Share '$UNRAID_SHARE' exists"
        exit 1
    fi
fi

# Create backup directory
echo ""
echo "Creating backup directory..."
sudo mkdir -p "$BACKUP_MOUNT/technitium"
sudo chown -R $(whoami):$(whoami) "$BACKUP_MOUNT/technitium"
echo "✅ Backup directory ready: $BACKUP_MOUNT/technitium"

echo ""
echo "Step 2: Test Manual Backup"
echo "==========================="
echo ""

cd "$REPO_DIR"

echo "Running test backup..."
if ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml; then
    echo "✅ Test backup successful!"
    echo ""
    echo "Backups created:"
    ls -lh "$BACKUP_MOUNT/technitium/"
else
    echo "❌ Test backup failed"
    echo "Please check the error messages above"
    exit 1
fi

echo ""
echo "Step 3: Setup Automated Daily Backups"
echo "======================================"
echo ""

# Create cron job
CRON_CMD="0 2 * * * cd $REPO_DIR && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml >> /tmp/dns-backup.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "technitium_daily_backup.yml"; then
    echo "✅ Cron job already exists"
else
    echo "Adding cron job for daily backups at $BACKUP_TIME..."
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    echo "✅ Cron job added"
fi

echo ""
echo "========================================="
echo "✅ Daily Backups Enabled Successfully!"
echo "========================================="
echo ""
echo "Configuration:"
echo "  - Backup Time: Daily at $BACKUP_TIME"
echo "  - Backup Location: $BACKUP_MOUNT/technitium/"
echo "  - Retention: 30 days"
echo "  - Log File: /tmp/dns-backup.log"
echo ""
echo "Next Steps:"
echo "  1. Verify backups tomorrow: ls -lh $BACKUP_MOUNT/technitium/"
echo "  2. Check logs: tail -f /tmp/dns-backup.log"
echo "  3. Test restore: See playbook/README_BACKUP_RESTORE.md"
echo ""
echo "To view cron jobs:"
echo "  crontab -l"
echo ""
echo "To disable backups:"
echo "  crontab -e  # Remove the technitium_daily_backup line"
echo ""
