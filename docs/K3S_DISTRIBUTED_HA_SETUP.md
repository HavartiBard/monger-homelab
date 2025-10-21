# K3s Distributed HA Setup - Maximum Resilience

## Overview

This creates a **truly distributed HA cluster** with control planes spread across ALL physical hosts:

- **pve1**: 1 K3s server (VM, 2GB RAM)
- **pve2**: 1 K3s server (VM, 2GB RAM)  
- **Unraid**: 1 K3s server + 5 workers (Docker, 24GB RAM)

**Total**: 8 nodes across 3 physical hosts

## Why This is Superior

### Survives ENTIRE Host Failure

| Host Down | Cluster Status | Reason |
|-----------|----------------|--------|
| **Unraid fails** | ✅ Cluster UP | pve1 + pve2 = 2/3 quorum |
| **pve1 fails** | ✅ Cluster UP | pve2 + Unraid = 2/3 quorum |
| **pve2 fails** | ✅ Cluster UP | pve1 + Unraid = 2/3 quorum |

### Survives Maintenance

| Maintenance | Impact | Strategy |
|-------------|--------|----------|
| **Unraid update** | No downtime | pve1+pve2 keep cluster alive |
| **Proxmox update** | No downtime | Update one at a time, Unraid+other keeps quorum |
| **Network issue** | Partial | Each host on different subnet/switch (optional) |

---

## Resource Impact

| Host | Component | RAM | CPU | Free After |
|------|-----------|-----|-----|------------|
| **pve1** | 1 control VM | 2GB | 2 cores | 1.3GB ✅ |
| **pve2** | 1 control VM | 2GB | 2 cores | 1.4GB ✅ |
| **Unraid** | 1 server + 5 workers | 24GB | ~6 cores | 36.6GB ✅ |

---

## Step-by-Step Deployment

### Phase 1: Deploy Proxmox VMs (10 minutes)

```bash
cd /opt/development/monger-homelab/terraform

# Deploy control planes on both Proxmox nodes
terraform apply -var-file=k3s-distributed-ha.auto.tfvars

# Note the IPs for both VMs
```

---

### Phase 2: Install K3s on Proxmox Servers (15 minutes)

#### 2a. Install First Server (pve1)

```bash
# SSH to k3s-server-1 on pve1
ssh james@k3s-server-1.klsll.com

# Install K3s as first server with cluster-init
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san k3s-server-1.klsll.com \
  --tls-san k3s-server-2.klsll.com \
  --tls-san k3s-server-3

# Wait for startup
sudo systemctl status k3s

# Get and SAVE the token
sudo cat /var/lib/rancher/k3s/server/node-token

# Verify first node
sudo k3s kubectl get nodes
```

#### 2b. Install Second Server (pve2)

```bash
# SSH to k3s-server-2 on pve2
ssh james@k3s-server-2.klsll.com

# Join the first server
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://k3s-server-1.klsll.com:6443 \
  --token YOUR_TOKEN_FROM_SERVER_1 \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san k3s-server-1.klsll.com \
  --tls-san k3s-server-2.klsll.com \
  --tls-san k3s-server-3

# Verify 2 nodes
sudo k3s kubectl get nodes
```

---

### Phase 3: Deploy Unraid Components (15 minutes)

#### 3a. Prepare Unraid

```bash
# On Unraid
mkdir -p /mnt/user/appdata/k3s-cluster/{server-3,agent-{1,2,3,4,5}}
mkdir -p /mnt/user/appdata/k3s-cluster/{server-3,agent-{1,2,3,4,5}}/kubelet
```

#### 3b. Copy Docker Compose

```bash
# From your dev machine
scp -r /opt/development/monger-homelab/unraid/k3s-cluster/ \
  root@unraid.klsll.com:/mnt/user/appdata/
```

#### 3c. Create .env with Token

```bash
# On Unraid
cd /mnt/user/appdata/k3s-cluster/

cat > .env << EOF
K3S_TOKEN=YOUR_TOKEN_FROM_PHASE_2
EOF
```

#### 3d. Start Unraid Server + Workers

```bash
# On Unraid
cd /mnt/user/appdata/k3s-cluster/

# Start all containers (1 server + 5 workers)
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f k3s-server-3
```

---

### Phase 4: Verify Distributed Cluster (5 minutes)

```bash
# Get kubeconfig from any server
scp james@k3s-server-1.klsll.com:/etc/rancher/k3s/k3s.yaml ~/.kube/config-homelab

# Update server address
sed -i 's/127.0.0.1/k3s-server-1.klsll.com/g' ~/.kube/config-homelab

# Use it
export KUBECONFIG=~/.kube/config-homelab

# Verify ALL 8 nodes across 3 hosts
kubectl get nodes -o wide
```

Expected output:
```
NAME            STATUS   ROLES                  AGE   VERSION        INTERNAL-IP
k3s-server-1    Ready    control-plane,master   10m   v1.28.5+k3s1   192.168.20.xxx (pve1)
k3s-server-2    Ready    control-plane,master   8m    v1.28.5+k3s1   192.168.20.xxx (pve2)
k3s-server-3    Ready    control-plane,master   5m    v1.28.5+k3s1   192.168.20.xxx (Unraid)
k3s-agent-1     Ready    <none>                 5m    v1.28.5+k3s1   192.168.20.xxx (Unraid)
k3s-agent-2     Ready    <none>                 5m    v1.28.5+k3s1   192.168.20.xxx (Unraid)
k3s-agent-3     Ready    <none>                 5m    v1.28.5+k3s1   192.168.20.xxx (Unraid)
k3s-agent-4     Ready    <none>                 5m    v1.28.5+k3s1   192.168.20.xxx (Unraid)
k3s-agent-5     Ready    <none>                 5m    v1.28.5+k3s1   192.168.20.xxx (Unraid)
```

Label workers:
```bash
kubectl label node k3s-agent-{1,2,3,4,5} node-role.kubernetes.io/worker=worker
```

---

### Phase 5: Install CI/CD Platform (20 minutes)

```bash
cd /opt/development/monger-homelab

# Bootstrap everything
./scripts/bootstrap-cicd.sh
```

---

## Testing Distributed HA

### Test 1: Lose Unraid

```bash
# Shutdown Unraid (or stop containers)
# From Unraid:
cd /mnt/user/appdata/k3s-cluster
docker-compose down

# From dev machine - cluster should still work!
kubectl get nodes
# k3s-server-3 and all agents will show NotReady
# But k3s-server-1 and k3s-server-2 maintain quorum

# Deploy a test workload
kubectl create deployment nginx --image=nginx --replicas=3

# It will fail to schedule (no workers available)
# But cluster is still accepting commands!

# Bring Unraid back
docker-compose up -d

# Pods will schedule
kubectl get pods -o wide
```

### Test 2: Lose pve1

```bash
# Shutdown pve1 or stop k3s-server-1
ssh james@k3s-server-1 "sudo systemctl stop k3s"

# Cluster stays up!
kubectl get nodes
# k3s-server-2 + k3s-server-3 (Unraid) = 2/3 quorum

# Workloads keep running on Unraid workers
kubectl get pods -o wide

# Bring it back
ssh james@k3s-server-1 "sudo systemctl start k3s"
```

### Test 3: Lose pve2

Same as Test 2 - cluster survives with pve1 + Unraid.

---

## Node Affinity Strategies

### Keep Critical Services on Specific Hosts

```yaml
# Example: Keep monitoring on Unraid (most reliable)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                - k3s-agent-1
                - k3s-agent-2
                - k3s-agent-3
                - k3s-agent-4
                - k3s-agent-5
```

### Spread Across Hosts

```yaml
# Anti-affinity to spread replicas across different physical hosts
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - my-app
              topologyKey: kubernetes.io/hostname
```

---

## Maintenance Procedures

### Updating Unraid

```bash
# 1. Drain Unraid nodes first
kubectl drain k3s-server-3 --ignore-daemonsets --delete-emptydir-data
kubectl drain k3s-agent-{1,2,3,4,5} --ignore-daemonsets --delete-emptydir-data

# 2. Update Unraid
# Proxmox nodes keep cluster alive!

# 3. Restart Docker containers
cd /mnt/user/appdata/k3s-cluster
docker-compose up -d

# 4. Uncordon
kubectl uncordon k3s-server-3
kubectl uncordon k3s-agent-{1,2,3,4,5}
```

### Updating Proxmox

```bash
# Update ONE at a time

# 1. Drain pve1
kubectl drain k3s-server-1 --ignore-daemonsets

# 2. Update pve1
# pve2 + Unraid keep quorum!

# 3. Uncordon
kubectl uncordon k3s-server-1

# 4. Repeat for pve2
```

---

## Monitoring Host Distribution

```bash
# See which pods are on which hosts
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c

# See node distribution
kubectl get nodes --show-labels | grep kubernetes.io/hostname
```

---

## Next Steps

1. ✅ **Deploy monitoring stack**
2. ✅ **Configure pod anti-affinity** for critical services
3. ✅ **Test failover scenarios**
4. ✅ **Setup automated backups** (etcd snapshots)
5. ✅ **Configure External Secrets Operator**

---

**You now have maximum resilience for a homelab!** 🚀

This survives any single host failure - a setup most enterprises would be jealous of!
