# Quick Resource Check

## Run These Commands on Each Proxmox Node

### Via Web Shell (Proxmox UI)

1. Open Proxmox web UI: https://pve1.klsll.com:8006 or https://pve2.klsll.com:8006
2. Click on the node (pve1 or pve2) in the left sidebar
3. Click "Shell" button
4. Copy and paste the commands below

### Via SSH

```bash
# From your dev machine
ssh james@pve1.klsll.com
# or
ssh james@pve2.klsll.com
```

---

## Commands to Run

```bash
echo "============================================"
echo "Resource Check for $(hostname)"
echo "============================================"
echo ""

echo "=== CPU Resources ==="
echo "Total Cores: $(nproc)"
top -bn1 | grep "Cpu(s)" | awk '{print "Current Usage: " $2 " user, " $4 " system, " $8 " idle"}'
echo ""

echo "=== Memory Resources ==="
free -h | grep -E "Mem:|Swap:"
echo ""
echo "Memory Breakdown:"
free -h | awk 'NR==2{printf "  Total: %s\n  Used: %s\n  Free: %s\n  Available: %s\n", $2,$3,$4,$7}'
echo ""

echo "=== Storage ==="
echo "ZFS Pools:"
pvesm status | grep -E "local-lvm|local-zfs" || echo "  No ZFS configured"
echo ""
echo "Main Storage:"
df -h / | awk 'NR==2{printf "  Total: %s\n  Used: %s\n  Available: %s\n  Use%%: %s\n", $2,$3,$4,$5}'
echo ""

echo "=== Current VMs ==="
qm list 2>/dev/null | awk 'NR>1{total++; if($3=="running") running++} END{print "  Total: " total "\n  Running: " running}'
echo "Running VMs:"
qm list 2>/dev/null | awk 'NR>1 && $3=="running"{print "  - " $2 " (ID: " $1 ")"}'
echo ""

echo "=== Current LXC Containers ==="
pct list 2>/dev/null | awk 'NR>1{total++; if($2=="running") running++} END{print "  Total: " total "\n  Running: " running}'
echo "Running Containers:"
pct list 2>/dev/null | awk 'NR>1 && $2=="running"{print "  - " $3 " (ID: " $1 ")"}'
echo ""

echo "============================================"
echo "Summary"
echo "============================================"
free -h | awk 'NR==2{
    total=$2; 
    avail=$7;
    print "Available RAM: " avail " of " total
}'
echo "Available CPU: $(nproc) cores (check usage above)"
echo ""
```

---

## Copy & Paste Version (Single Command)

Run this on **pve1**:

```bash
echo "=== PVE1 Resources ===" && echo "CPU: $(nproc) cores" && free -h | awk 'NR==2{print "RAM: "$7" available of "$2}' && echo "VMs: $(qm list 2>/dev/null | awk 'NR>1 && $3=="running"' | wc -l) running" && echo "LXC: $(pct list 2>/dev/null | awk 'NR>1 && $2=="running"' | wc -l) running"
```

Run this on **pve2**:

```bash
echo "=== PVE2 Resources ===" && echo "CPU: $(nproc) cores" && free -h | awk 'NR==2{print "RAM: "$7" available of "$2}' && echo "VMs: $(qm list 2>/dev/null | awk 'NR>1 && $3=="running"' | wc -l) running" && echo "LXC: $(pct list 2>/dev/null | awk 'NR>1 && $2=="running"' | wc -l) running"
```

---

## Paste the Results Here

After running the commands, paste the output and I'll:

1. ✅ Analyze your available resources
2. ✅ Recommend the best deployment option
3. ✅ Create custom tfvars for your situation
4. ✅ Adjust the implementation plan

---

## About Unraid Integration

If you want to use Unraid for K3s workers:

### Check Unraid Resources

Via Unraid web UI or SSH:

```bash
echo "=== Unraid Resources ==="
echo "CPU: $(nproc) cores"
free -h | awk 'NR==2{print "RAM: "$7" available of "$2}'
docker ps --format "table {{.Names}}\t{{.Status}}" | head -10
echo ""
echo "Docker containers using: $(docker stats --no-stream --format "{{.MemUsage}}" | awk -F'/' '{sum+=$1} END{print sum}')"
```

---

## Quick Recommendations Based on Available RAM

| Available RAM | Recommended Deployment |
|---------------|----------------------|
| **24GB+** | Option 1: Full Production Cluster (7 VMs) |
| **12-24GB** | Option 2: Minimal Cluster (3-4 VMs) |
| **8-12GB** | Option 3: Hybrid Proxmox + Unraid |
| **4-8GB** | Option 4: K3s on Unraid Only |
| **<4GB** | Option 5: Single-Node (testing only) |

See full details in `docs/RESOURCE_CONSTRAINED_OPTIONS.md`
