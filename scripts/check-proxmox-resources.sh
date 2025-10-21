#!/bin/bash
# Check Proxmox Resource Usage
# Queries both Proxmox nodes to determine available resources

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Proxmox Resource Availability Check${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

# Proxmox API credentials (from 1Password/Terraform)
PVE1_API="https://pve1.klsll.com:8006/api2/json"
PVE2_API="https://pve2.klsll.com:8006/api2/json"

# Get token from environment or 1Password
if [ -z "$PROXMOX_TOKEN_ID" ]; then
    PROXMOX_TOKEN_ID="root@pam!terraform_admin"
fi

if [ -z "$PROXMOX_TOKEN_SECRET" ]; then
    echo -e "${YELLOW}⚠️  PROXMOX_TOKEN_SECRET not set${NC}"
    echo "Trying to get from 1Password..."
    
    if command -v op &> /dev/null; then
        export OP_SERVICE_ACCOUNT_TOKEN="${OP_SERVICE_ACCOUNT_TOKEN}"
        PROXMOX_TOKEN_SECRET=$(op read "op://homelab/Proxmox Terraform/credential" 2>/dev/null || echo "")
    fi
    
    if [ -z "$PROXMOX_TOKEN_SECRET" ]; then
        echo -e "${RED}❌ Could not get Proxmox token${NC}"
        echo "Set PROXMOX_TOKEN_SECRET environment variable"
        exit 1
    fi
fi

# Function to query Proxmox API
query_proxmox() {
    local api_url=$1
    local endpoint=$2
    
    curl -s -k -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
        "${api_url}${endpoint}"
}

# Function to format bytes to GB
bytes_to_gb() {
    echo "scale=2; $1 / 1073741824" | bc
}

# Function to check node resources
check_node() {
    local node_name=$1
    local api_url=$2
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Node: ${node_name}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Get node status
    node_status=$(query_proxmox "$api_url" "/nodes/${node_name}/status")
    
    if [ $? -ne 0 ] || [ -z "$node_status" ]; then
        echo -e "${RED}❌ Could not connect to ${node_name}${NC}\n"
        return 1
    fi
    
    # Parse JSON (using jq if available, otherwise basic parsing)
    if command -v jq &> /dev/null; then
        # CPU
        cpu_total=$(echo "$node_status" | jq -r '.data.cpuinfo.cpus // 0')
        cpu_usage=$(echo "$node_status" | jq -r '.data.cpu // 0')
        cpu_used=$(echo "scale=2; $cpu_total * $cpu_usage" | bc)
        cpu_available=$(echo "scale=2; $cpu_total - $cpu_used" | bc)
        
        # Memory (in bytes)
        mem_total=$(echo "$node_status" | jq -r '.data.memory.total // 0')
        mem_used=$(echo "$node_status" | jq -r '.data.memory.used // 0')
        mem_free=$(echo "$node_status" | jq -r '.data.memory.free // 0')
        mem_total_gb=$(bytes_to_gb $mem_total)
        mem_used_gb=$(bytes_to_gb $mem_used)
        mem_free_gb=$(bytes_to_gb $mem_free)
        
        # Storage
        storage_info=$(query_proxmox "$api_url" "/nodes/${node_name}/storage")
        
        echo -e "${GREEN}CPU Resources:${NC}"
        echo -e "  Total Cores:     ${cpu_total}"
        echo -e "  Current Usage:   ${cpu_used} cores ($(echo "scale=1; $cpu_usage * 100" | bc)%)"
        echo -e "  Available:       ${cpu_available} cores"
        
        echo -e "\n${GREEN}Memory Resources:${NC}"
        echo -e "  Total RAM:       ${mem_total_gb} GB"
        echo -e "  Used RAM:        ${mem_used_gb} GB"
        echo -e "  Available RAM:   ${mem_free_gb} GB"
        
        # Get VM list
        vm_list=$(query_proxmox "$api_url" "/nodes/${node_name}/qemu")
        vm_count=$(echo "$vm_list" | jq -r '.data | length')
        
        echo -e "\n${GREEN}Virtual Machines:${NC}"
        echo -e "  Total VMs:       ${vm_count}"
        
        if [ "$vm_count" -gt 0 ]; then
            echo -e "\n  Running VMs:"
            echo "$vm_list" | jq -r '.data[] | select(.status == "running") | "    - \(.name) (VMID: \(.vmid)) - \(.maxmem / 1073741824 | floor)GB RAM, \(.cpus) cores"'
        fi
        
        # Get LXC list
        lxc_list=$(query_proxmox "$api_url" "/nodes/${node_name}/lxc")
        lxc_count=$(echo "$lxc_list" | jq -r '.data | length')
        
        echo -e "\n${GREEN}LXC Containers:${NC}"
        echo -e "  Total Containers: ${lxc_count}"
        
        if [ "$lxc_count" -gt 0 ]; then
            echo -e "\n  Running Containers:"
            echo "$lxc_list" | jq -r '.data[] | select(.status == "running") | "    - \(.name) (CTID: \(.vmid)) - \(.maxmem / 1073741824 | floor)GB RAM"'
        fi
        
    else
        echo -e "${YELLOW}⚠️  jq not installed - showing raw data${NC}"
        echo "$node_status"
    fi
    
    echo ""
}

# Check both nodes
check_node "pve1" "$PVE1_API"
check_node "pve2" "$PVE2_API"

# Summary
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Resource Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}K3s Cluster Requirements:${NC}"
echo -e "  Control Plane (3 VMs):  12GB RAM, 6 CPU cores"
echo -e "  Workers (4 VMs):        16GB RAM, 8 CPU cores"
echo -e "  CI/CD Overhead:         8GB RAM, 4 CPU cores"
echo -e "  ${CYAN}Total Needed:           ~36GB RAM, ~18 CPU cores${NC}\n"

echo -e "${GREEN}Recommendations:${NC}"
echo -e "  1. If insufficient resources: Scale down to minimal cluster"
echo -e "     - 1 control plane + 2 workers = ~12GB RAM, ~6 cores"
echo -e "  2. Use Unraid for additional worker nodes (K3s supports mixed clusters)"
echo -e "  3. Deploy only essential services initially (ArgoCD + basic monitoring)\n"

echo -e "${CYAN}Alternative: Lightweight K3s on Unraid${NC}"
echo -e "  - Run K3s server on Proxmox (1 VM: 4GB RAM, 2 cores)"
echo -e "  - Run K3s agents on Unraid (Docker containers)"
echo -e "  - Much lower resource footprint\n"
