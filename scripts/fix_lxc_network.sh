#!/bin/bash
# Fix LXC network connectivity issues

LXC_ID=104  # Update if different
LXC_IP="192.168.20.50"

echo "========================================="
echo "LXC Network Troubleshooting"
echo "========================================="
echo ""

# Check from Proxmox host
echo "Step 1: Check LXC status from Proxmox host"
echo "-------------------------------------------"
ssh root@192.168.20.100 << 'EOF'
pct list | grep automation
pct config 104 | grep -E "net0|ip"
EOF

echo ""
echo "Step 2: Enter LXC and check network"
echo "------------------------------------"
ssh root@192.168.20.100 << 'EOF'
pct enter 104 << 'INNER'
echo "Network interfaces:"
ip addr show

echo ""
echo "Routes:"
ip route show

echo ""
echo "DNS:"
cat /etc/resolv.conf

echo ""
echo "Ping gateway:"
ping -c 2 192.168.20.1

echo ""
echo "Ping DNS:"
ping -c 2 192.168.20.29
exit
INNER
EOF

echo ""
echo "========================================="
echo "Common Fixes:"
echo "========================================="
echo ""
echo "1. Restart network in LXC:"
echo "   pct enter 104"
echo "   systemctl restart networking"
echo ""
echo "2. Restart LXC container:"
echo "   pct stop 104 && pct start 104"
echo ""
echo "3. Check firewall on Proxmox:"
echo "   pve-firewall status"
echo ""
