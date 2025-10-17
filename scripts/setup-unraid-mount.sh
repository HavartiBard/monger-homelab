#!/bin/bash
# Setup Unraid NFS mount for DNS backups
# Run this on your Ansible control machine (WSL)

set -e

UNRAID_IP="192.168.20.5"
UNRAID_SHARE="backups"
MOUNT_POINT="/mnt/unraid-backups"
BACKUP_DIR="${MOUNT_POINT}/technitium"

echo "=========================================="
echo "Unraid NFS Mount Setup for DNS Backups"
echo "=========================================="
echo "Unraid: ${UNRAID_IP}"
echo "Mount: ${MOUNT_POINT}"
echo ""

# Install NFS client if not present
echo "[1/5] Installing NFS client..."
if ! command -v mount.nfs &> /dev/null; then
    sudo apt update
    sudo apt install -y nfs-common
fi

# Create mount point
echo "[2/5] Creating mount point..."
sudo mkdir -p ${MOUNT_POINT}

# Check if already mounted
if mountpoint -q ${MOUNT_POINT}; then
    echo "[3/5] Already mounted, unmounting first..."
    sudo umount ${MOUNT_POINT}
fi

# Mount NFS share
echo "[3/5] Mounting Unraid NFS share..."
sudo mount -t nfs ${UNRAID_IP}:/mnt/user/${UNRAID_SHARE} ${MOUNT_POINT}

# Verify mount
if mountpoint -q ${MOUNT_POINT}; then
    echo "✅ Mount successful!"
else
    echo "❌ Mount failed!"
    exit 1
fi

# Create backup directory
echo "[4/5] Creating backup directory..."
sudo mkdir -p ${BACKUP_DIR}
sudo chown -R $(whoami):$(whoami) ${BACKUP_DIR}

# Add to fstab for persistent mount
echo "[5/5] Adding to /etc/fstab for persistent mount..."
FSTAB_ENTRY="${UNRAID_IP}:/mnt/user/${UNRAID_SHARE} ${MOUNT_POINT} nfs defaults,_netdev 0 0"

if ! grep -q "${MOUNT_POINT}" /etc/fstab; then
    echo "${FSTAB_ENTRY}" | sudo tee -a /etc/fstab
    echo "✅ Added to /etc/fstab"
else
    echo "⚠️  Already in /etc/fstab"
fi

# Test write access
echo ""
echo "Testing write access..."
TEST_FILE="${BACKUP_DIR}/test-$(date +%s).txt"
echo "Test backup file" > ${TEST_FILE}
if [ -f ${TEST_FILE} ]; then
    echo "✅ Write test successful!"
    rm ${TEST_FILE}
else
    echo "❌ Write test failed!"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo "Mount point: ${MOUNT_POINT}"
echo "Backup directory: ${BACKUP_DIR}"
echo ""
echo "Next steps:"
echo "1. Run test backup: ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml"
echo "2. Set up cron job for daily backups"
echo ""
