#!/bin/bash
# Check Proxmox Resources via SSH
# Simpler alternative that doesn't require API tokens

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

NODES=("pve1.klsll.com" "pve2.klsll.com")
SSH_USER="${SSH_USER:-james}"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Proxmox Resource Check (via SSH)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

# Function to bytes to GB
bytes_to_gb() {
    awk "BEGIN {printf \"%.2f\", $1/1024/1024/1024}"
}

# Function to check node
check_node_ssh() {
    local node=$1
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Node: ${node}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Check if we can SSH
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes ${SSH_USER}@${node} "exit" 2>/dev/null; then
        echo -e "${RED}❌ Cannot SSH to ${node} (check SSH keys)${NC}\n"
        return 1
    fi
    
    # Get CPU info
    echo -e "${GREEN}CPU Resources:${NC}"
    ssh ${SSH_USER}@${node} "
        cpu_cores=\$(nproc)
        cpu_usage=\$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1)
        echo \"  Total Cores:     \$cpu_cores\"
        echo \"  Current Usage:   \${cpu_usage}%\"
        echo \"  Available:       ~\$(echo \"scale=1; \$cpu_cores * (100 - \$cpu_usage) / 100\" | bc) cores\"
    "
    
    # Get Memory info
    echo -e "\n${GREEN}Memory Resources:${NC}"
    ssh ${SSH_USER}@${node} "
        mem_total=\$(free -b | awk '/^Mem:/ {print \$2}')
        mem_used=\$(free -b | awk '/^Mem:/ {print \$3}')
        mem_available=\$(free -b | awk '/^Mem:/ {print \$7}')
        
        mem_total_gb=\$(echo \"scale=2; \$mem_total / 1024 / 1024 / 1024\" | bc)
        mem_used_gb=\$(echo \"scale=2; \$mem_used / 1024 / 1024 / 1024\" | bc)
        mem_avail_gb=\$(echo \"scale=2; \$mem_available / 1024 / 1024 / 1024\" | bc)
        
        echo \"  Total RAM:       \${mem_total_gb} GB\"
        echo \"  Used RAM:        \${mem_used_gb} GB\"
        echo \"  Available RAM:   \${mem_avail_gb} GB\"
    "
    
    # Get storage info
    echo -e "\n${GREEN}Storage (local-zfs):${NC}"
    ssh ${SSH_USER}@${node} "
        if command -v pvesm &> /dev/null; then
            pvesm status | grep -E 'local-lvm|local-zfs' || echo '  No ZFS storage configured'
        else
            df -h / | tail -1 | awk '{print \"  Root:  \" \$2 \" total, \" \$4 \" available\"}'
        fi
    "
    
    # Get VM/LXC count
    echo -e "\n${GREEN}Virtual Machines & Containers:${NC}"
    ssh ${SSH_USER}@${node} "
        if command -v qm &> /dev/null; then
            vm_count=\$(qm list 2>/dev/null | tail -n +2 | wc -l)
            echo \"  VMs:        \$vm_count\"
            
            if [ \$vm_count -gt 0 ]; then
                echo -e \"\n  Running VMs:\"
                qm list 2>/dev/null | tail -n +2 | grep running | awk '{print \"    - \" \$2 \" (ID: \" \$1 \")\"}'
            fi
        fi
        
        if command -v pct &> /dev/null; then
            lxc_count=\$(pct list 2>/dev/null | tail -n +2 | wc -l)
            echo \"  Containers: \$lxc_count\"
            
            if [ \$lxc_count -gt 0 ]; then
                echo -e \"\n  Running Containers:\"
                pct list 2>/dev/null | tail -n +2 | grep running | awk '{print \"    - \" \$3 \" (ID: \" \$1 \")\"}'
            fi
        fi
    "
    
    echo ""
}

# Check both nodes
for node in "${NODES[@]}"; do
    check_node_ssh "$node"
done

# Summary and recommendations
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Analysis & Recommendations${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Original K3s Plan (Full Cluster):${NC}"
echo -e "  3 Control Plane VMs:    12GB RAM, 6 cores"
echo -e "  4 Worker VMs:           16GB RAM, 8 cores"
echo -e "  CI/CD Overhead:         8GB RAM, 4 cores"
echo -e "  ${CYAN}Total:                  36GB RAM, 18 cores${NC}\n"

echo -e "${GREEN}Option 1: Minimal K3s Cluster (Recommended if tight on resources)${NC}"
echo -e "  1 Control Plane VM:     4GB RAM, 2 cores"
echo -e "  2 Worker VMs:           8GB RAM, 4 cores"
echo -e "  ${CYAN}Total:                  12GB RAM, 6 cores${NC}"
echo -e "  ✅ Still production-capable"
echo -e "  ✅ Can scale up later\n"

echo -e "${GREEN}Option 2: Hybrid Proxmox + Unraid${NC}"
echo -e "  On Proxmox:"
echo -e "    1 Control Plane VM:   4GB RAM, 2 cores"
echo -e "  On Unraid (Docker):"
echo -e "    2-3 K3s agent containers"
echo -e "  ${CYAN}Proxmox need:           4GB RAM, 2 cores${NC}"
echo -e "  ✅ Leverages Unraid resources"
echo -e "  ✅ K3s supports heterogeneous clusters\n"

echo -e "${GREEN}Option 3: K3s on Unraid Only${NC}"
echo -e "  K3s server + agents in Docker on Unraid"
echo -e "  ${CYAN}Proxmox need:           0GB RAM, 0 cores${NC}"
echo -e "  ✅ Frees all Proxmox resources"
echo -e "  ✅ Simpler deployment"
echo -e "  ⚠️  Less enterprise-like (no VM isolation)\n"

echo -e "${CYAN}Next Steps:${NC}"
echo -e "  1. Review resources above"
echo -e "  2. Choose deployment option"
echo -e "  3. I can create tfvars files for each option"
echo -e "  4. I can also create docker-compose for Unraid K3s\n"
