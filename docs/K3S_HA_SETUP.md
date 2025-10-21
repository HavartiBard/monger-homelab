# K3s High Availability Setup Guide

## Overview

This guide sets up a **true HA K3s cluster** with:
- **3 control plane nodes** on Proxmox (etcd quorum)
- **5 worker nodes** on Unraid (Docker containers)
- **Total**: 8 nodes, 26GB RAM

## Architecture

```
Control Plane (Proxmox) - HA with Quorum
┌─────────────────────────────────────────┐
│ pve1                                    │
│  ├─ k3s-server-1 (2GB) - Leader         │
│  └─ k3s-server-2 (2GB) - Member         │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ pve2                                    │
│  └─ k3s-server-3 (2GB) - Member         │
└─────────────────────────────────────────┘

Workers (Unraid) - Capacity & Redundancy
┌─────────────────────────────────────────┐
│ k3s-agent-1 (4GB)                       │
│ k3s-agent-2 (4GB)                       │
│ k3s-agent-3 (4GB)                       │
│ k3s-agent-4 (4GB)                       │
│ k3s-agent-5 (4GB)                       │
└─────────────────────────────────────────┘
```

## Benefits of This Setup

### High Availability
- ✅ **Control plane survives 1 node failure** (2/3 quorum)
- ✅ **Workloads survive multiple worker failures** (5 workers)
- ✅ **No single point of failure**
- ✅ **Automatic failover and rescheduling**

### Resource Efficiency
- ✅ **6GB RAM on Proxmox** (all available resources used)
- ✅ **20GB RAM on Unraid** (only 33% of 60GB)
- ✅ **40GB headroom** for future expansion

### Enterprise-Grade
- ✅ **Production HA configuration**
- ✅ **Meets k8s best practices**
- ✅ **Can run critical workloads**

---

## Step-by-Step Deployment

### Phase 1: Deploy Control Plane VMs (15 minutes)

```bash
cd /opt/development/monger-homelab/terraform

# Deploy all 3 control plane VMs
terraform apply -var-file=k3s-hybrid-ha.auto.tfvars

# Note the IPs of all 3 VMs
# You'll need these for the next steps
```

Wait for all 3 VMs to boot (2-3 minutes each).

---

### Phase 2: Install K3s on Control Plane (20 minutes)

#### 2a. Install First Server (k3s-server-1)

```bash
# SSH to first server
ssh james@k3s-server-1.klsll.com  # Or use IP

# Install K3s as first server with cluster-init
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san k3s-server-1.klsll.com \
  --tls-san k3s-server-2.klsll.com \
  --tls-san k3s-server-3.klsll.com

# Wait for K3s to start (30 seconds)
sudo systemctl status k3s

# Get the server token (SAVE THIS!)
sudo cat /var/lib/rancher/k3s/server/node-token

# Verify first node is ready
sudo k3s kubectl get nodes
```

**Save the token!** Format: `K107c5e4b8a::server:1234567890abcdef`

#### 2b. Install Second Server (k3s-server-2)

```bash
# SSH to second server
ssh james@k3s-server-2.klsll.com

# Install K3s and JOIN the first server
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://k3s-server-1.klsll.com:6443 \
  --token YOUR_TOKEN_FROM_SERVER_1 \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san k3s-server-1.klsll.com \
  --tls-san k3s-server-2.klsll.com \
  --tls-san k3s-server-3.klsll.com

# Verify it joined
sudo k3s kubectl get nodes
# Should show 2 nodes now
```

#### 2c. Install Third Server (k3s-server-3)

```bash
# SSH to third server
ssh james@k3s-server-3.klsll.com

# Install K3s and JOIN the first server
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://k3s-server-1.klsll.com:6443 \
  --token YOUR_TOKEN_FROM_SERVER_1 \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san k3s-server-1.klsll.com \
  --tls-san k3s-server-2.klsll.com \
  --tls-san k3s-server-3.klsll.com

# Verify all 3 are ready
sudo k3s kubectl get nodes
# Should show 3 control-plane nodes
```

---

### Phase 3: Configure kubectl Access (5 minutes)

```bash
# From your dev machine
# Get kubeconfig from any server (they're all the same)
scp james@k3s-server-1.klsll.com:/etc/rancher/k3s/k3s.yaml ~/.kube/config-homelab

# Update server address to point to any control plane
# (or use a load balancer VIP if you set one up)
sed -i 's/127.0.0.1/k3s-server-1.klsll.com/g' ~/.kube/config-homelab

# Set KUBECONFIG
export KUBECONFIG=~/.kube/config-homelab

# Verify HA cluster
kubectl get nodes -o wide
```

Expected output:
```
NAME            STATUS   ROLES                       AGE   VERSION
k3s-server-1    Ready    control-plane,etcd,master   5m    v1.28.5+k3s1
k3s-server-2    Ready    control-plane,etcd,master   3m    v1.28.5+k3s1
k3s-server-3    Ready    control-plane,etcd,master   1m    v1.28.5+k3s1
```

---

### Phase 4: Deploy Unraid Workers (15 minutes)

#### 4a. Prepare Unraid

```bash
# On Unraid (via SSH or web UI terminal)
mkdir -p /mnt/user/appdata/k3s-agents/agent-{1,2,3,4,5}
mkdir -p /mnt/user/appdata/k3s-agents/agent-{1,2,3,4,5}/kubelet
```

#### 4b. Copy Docker Compose

```bash
# From your dev machine
scp /opt/development/monger-homelab/unraid/k3s-agents/docker-compose-5workers.yml \
  root@unraid.klsll.com:/mnt/user/appdata/k3s-agents/docker-compose.yml

scp /opt/development/monger-homelab/unraid/k3s-agents/.env.example \
  root@unraid.klsll.com:/mnt/user/appdata/k3s-agents/
```

#### 4c. Create .env with Token

```bash
# On Unraid
cd /mnt/user/appdata/k3s-agents/

# Create .env file
cat > .env << EOF
K3S_TOKEN=YOUR_TOKEN_FROM_PHASE_2
EOF
```

#### 4d. Start Workers

```bash
# On Unraid
cd /mnt/user/appdata/k3s-agents/

# Start all 5 workers
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

---

### Phase 5: Verify Complete Cluster (5 minutes)

```bash
# From your dev machine
kubectl get nodes

# Should show 8 nodes:
# - 3 control-plane (Proxmox)
# - 5 workers (Unraid)
```

Expected output:
```
NAME            STATUS   ROLES                       AGE   VERSION
k3s-server-1    Ready    control-plane,etcd,master   20m   v1.28.5+k3s1
k3s-server-2    Ready    control-plane,etcd,master   18m   v1.28.5+k3s1
k3s-server-3    Ready    control-plane,etcd,master   16m   v1.28.5+k3s1
k3s-agent-1     Ready    <none>                      5m    v1.28.5+k3s1
k3s-agent-2     Ready    <none>                      5m    v1.28.5+k3s1
k3s-agent-3     Ready    <none>                      5m    v1.28.5+k3s1
k3s-agent-4     Ready    <none>                      5m    v1.28.5+k3s1
k3s-agent-5     Ready    <none>                      5m    v1.28.5+k3s1
```

Label the workers:
```bash
kubectl label node k3s-agent-{1,2,3,4,5} node-role.kubernetes.io/worker=worker
```

---

### Phase 6: Install CI/CD Platform (20 minutes)

```bash
cd /opt/development/monger-homelab

# Bootstrap ArgoCD, Tekton, etc.
./scripts/bootstrap-cicd.sh

# This installs:
# - ArgoCD (GitOps)
# - Tekton (CI pipelines)
# - External Secrets Operator
# - Custom tasks and pipelines
```

---

## Testing High Availability

### Test 1: Lose One Control Plane

```bash
# Shutdown one control plane
ssh james@k3s-server-3 "sudo systemctl stop k3s"

# Cluster should still work
kubectl get nodes
# k3s-server-3 will show NotReady, but cluster still functions

# Deploy a test app
kubectl create deployment nginx --image=nginx --replicas=3
kubectl get pods -o wide
# Pods will deploy normally

# Bring it back
ssh james@k3s-server-3 "sudo systemctl start k3s"
```

### Test 2: Lose Multiple Workers

```bash
# On Unraid, stop 2 workers
cd /mnt/user/appdata/k3s-agents
docker-compose stop k3s-agent-4 k3s-agent-5

# Workloads should reschedule to remaining workers
kubectl get pods -o wide
# Watch pods move to agents 1, 2, 3

# Bring them back
docker-compose start k3s-agent-4 k3s-agent-5
```

---

## Resource Usage After Deployment

### Proxmox

| Node | Before | Control Planes | After |
|------|--------|----------------|-------|
| pve1 | 3.3GB free | 2 × 2GB | ~0GB free ⚠️ |
| pve2 | 3.4GB free | 1 × 2GB | ~1.4GB free |

### Unraid

| Resource | Before | Workers | After | % Used |
|----------|--------|---------|-------|--------|
| RAM | 60.6GB free | 5 × 4GB | 40.6GB free | 33% |
| CPU | 2% load | Light | ~10-20% | Normal |

---

## Maintenance

### Updating K3s

Update one control plane at a time:

```bash
# Server 1
ssh james@k3s-server-1
curl -sfL https://get.k3s.io | sh -

# Wait 2 minutes, verify cluster health
kubectl get nodes

# Server 2
ssh james@k3s-server-2
curl -sfL https://get.k3s.io | sh -

# Wait, verify

# Server 3
ssh james@k3s-server-3
curl -sfL https://get.k3s.io | sh -
```

Update workers:
```bash
# On Unraid
cd /mnt/user/appdata/k3s-agents
docker-compose pull
docker-compose up -d
```

---

## Scaling

### Add More Workers

Edit `docker-compose.yml`, add k3s-agent-6, then:
```bash
docker-compose up -d k3s-agent-6
```

### Remove Workers

```bash
# Drain first
kubectl drain k3s-agent-5 --ignore-daemonsets --delete-emptydir-data

# Delete from cluster
kubectl delete node k3s-agent-5

# Stop container
docker-compose stop k3s-agent-5
docker-compose rm k3s-agent-5
```

---

## Troubleshooting

### Control Plane Won't Join

Check connectivity between servers:
```bash
# From server-2 or server-3
curl -k https://k3s-server-1.klsll.com:6443
```

Check etcd status:
```bash
# On any control plane
sudo k3s kubectl get nodes
sudo k3s etcd-snapshot list
```

### Workers Won't Join

Check logs:
```bash
docker-compose logs k3s-agent-1
```

Common issues:
- Wrong token in .env
- Can't reach control plane (network/DNS issue)
- Ports blocked (6443, 10250)

---

## Next Steps

1. ✅ **Deploy monitoring**: `kubectl apply -f argocd/applications/monitoring-stack.yaml`
2. ✅ **Setup External Secrets**: Follow `docs/1PASSWORD_ESO_INTEGRATION.md`
3. ✅ **Deploy first application**: Test with sample workload
4. ✅ **Setup backups**: Automated etcd snapshots

---

**You now have an enterprise-grade HA Kubernetes cluster!** 🚀
