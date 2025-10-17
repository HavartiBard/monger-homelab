#!/bin/bash
# Setup NFS bind mount for automation LXC container
# This mounts Unraid NFS on Proxmox host and bind-mounts into the container

set -e

PROXMOX_HOST="192.168.20.100"
LXC_ID="104"
UNRAID_IP="192.168.20.5"
UNRAID_SHARE="backups"
MOUNT_POINT="/mnt/unraid-backups"

echo "========================================="
echo "Setup NFS Bind Mount for Automation LXC"
echo "========================================="
echo ""

echo "Configuring Proxmox host: $PROXMOX_HOST"
ssh root@$PROXMOX_HOST << EOF
set -e

echo "[1/6] Installing NFS client..."
apt update -qq
apt install -y nfs-common

echo "[2/6] Creating mount point..."
mkdir -p $MOUNT_POINT

echo "[3/6] Mounting Unraid NFS share..."
if ! mountpoint -q $MOUNT_POINT; then
  mount -t nfs ${UNRAID_IP}:/mnt/user/${UNRAID_SHARE} $MOUNT_POINT
  echo "✅ Mounted successfully"
else
  echo "✅ Already mounted"
fi

echo "[4/6] Adding to fstab for persistence..."
if ! grep -q "$MOUNT_POINT" /etc/fstab; then
  echo "${UNRAID_IP}:/mnt/user/${UNRAID_SHARE} $MOUNT_POINT nfs defaults 0 0" >> /etc/fstab
  echo "✅ Added to fstab"
else
  echo "✅ Already in fstab"
fi

echo "[5/6] Adding bind mount to LXC config..."
if ! grep -q "mp0:" /etc/pve/lxc/${LXC_ID}.conf; then
  echo "mp0: ${MOUNT_POINT},mp=${MOUNT_POINT}" >> /etc/pve/lxc/${LXC_ID}.conf
  echo "✅ Bind mount added"
  NEED_RESTART=1
else
  echo "✅ Bind mount already configured"
  NEED_RESTART=0
fi

if [ "\$NEED_RESTART" = "1" ]; then
  echo "[6/6] Restarting LXC container..."
  pct stop ${LXC_ID}
  sleep 2
  pct start ${LXC_ID}
  echo "✅ Container restarted"
else
  echo "[6/6] No restart needed"
fi

echo ""
echo "Verifying configuration..."
echo "NFS mount on host:"
df -h | grep $MOUNT_POINT || echo "⚠️  Not mounted"

echo ""
echo "LXC config:"
grep mp0 /etc/pve/lxc/${LXC_ID}.conf || echo "⚠️  No bind mount"
EOF

echo ""
echo "Waiting for container to be ready..."
sleep 5

echo "Testing access from container..."
if ssh james@192.168.20.50 "ls -la $MOUNT_POINT" > /dev/null 2>&1; then
  echo "✅ Container can access $MOUNT_POINT"
  ssh james@192.168.20.50 "df -h | grep $MOUNT_POINT"
else
  echo "⚠️  Container cannot access $MOUNT_POINT yet (may need more time)"
fi

echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "The Unraid NFS share is now available at:"
echo "  Host: $MOUNT_POINT"
echo "  Container: $MOUNT_POINT"
echo ""
echo "Next step: Run bootstrap playbook"
echo "  cd /mnt/d/cluster/monger-homelab"
echo "  ansible-playbook -i inventory/raclette/inventory.ini playbook/bootstrap_automation_lxc.yml"
echo ""
