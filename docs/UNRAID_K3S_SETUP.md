# Unraid K3s Agent Setup Guide

## Overview

This guide sets up K3s agent nodes on your Unraid server that connect to the K3s control plane running on Proxmox.

**Your Hybrid Cluster:**
- **Proxmox pve2**: 1 K3s server (control plane) - 2GB RAM
- **Unraid**: 3 K3s agents (workers) - 12GB RAM total

## Prerequisites

- ✅ Unraid 6.9+ with Docker support
- ✅ K3s server deployed on Proxmox
- ✅ Network connectivity between Unraid and Proxmox VLAN 20
- ✅ DNS resolution for k3s-server.klsll.com

## Step-by-Step Deployment

### Step 1: Deploy K3s Server on Proxmox

```bash
# On your dev machine
cd /opt/development/monger-homelab/terraform

# Deploy the single K3s server VM
terraform apply -var-file=k3s-hybrid-unraid.auto.tfvars

# Wait for VM to boot (2-3 minutes)
```

### Step 2: Install K3s on the Server VM

```bash
# SSH to the new VM
ssh james@k3s-server.klsll.com  # Or use IP from terraform output

# Install K3s server
curl -sfL https://get.k3s.io | sh -s - server \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san k3s-server.klsll.com

# Verify K3s is running
sudo systemctl status k3s

# Get the node token (save this!)
sudo cat /var/lib/rancher/k3s/server/node-token
```

**Save the token!** It will look like: `K107c5e4b8a::server:1234567890abcdef`

### Step 3: Get Kubeconfig for Local kubectl

```bash
# From your dev machine
scp james@k3s-server.klsll.com:/etc/rancher/k3s/k3s.yaml ~/.kube/config-homelab

# Edit the config file to use the correct server address
sed -i 's/127.0.0.1/k3s-server.klsll.com/g' ~/.kube/config-homelab

# Set KUBECONFIG
export KUBECONFIG=~/.kube/config-homelab

# Verify connection
kubectl get nodes
```

You should see one node (the server):
```
NAME         STATUS   ROLES                  AGE   VERSION
k3s-server   Ready    control-plane,master   1m    v1.28.5+k3s1
```

### Step 4: Setup Unraid K3s Agents

#### 4a. Create Directory Structure on Unraid

Via Unraid web UI terminal or SSH:

```bash
# Create base directory
mkdir -p /mnt/user/appdata/k3s-agents

# Create agent data directories
mkdir -p /mnt/user/appdata/k3s-agents/agent-{1,2,3}
mkdir -p /mnt/user/appdata/k3s-agents/agent-{1,2,3}/kubelet
```

#### 4b. Copy Docker Compose Files

From your dev machine:

```bash
# Copy docker-compose.yml to Unraid
scp /opt/development/monger-homelab/unraid/k3s-agents/docker-compose.yml \
  root@unraid.klsll.com:/mnt/user/appdata/k3s-agents/

# Copy .env.example
scp /opt/development/monger-homelab/unraid/k3s-agents/.env.example \
  root@unraid.klsll.com:/mnt/user/appdata/k3s-agents/
```

#### 4c. Create .env File with Token

On Unraid:

```bash
cd /mnt/user/appdata/k3s-agents/

# Create .env file with your K3s token
cat > .env << EOF
K3S_TOKEN=YOUR_TOKEN_FROM_STEP_2
EOF

# Verify
cat .env
```

Replace `YOUR_TOKEN_FROM_STEP_2` with the actual token from the Proxmox server.

### Step 5: Deploy K3s Agents on Unraid

#### Option A: Via Unraid Docker Compose Manager Plugin

1. Install "Compose.Manager" plugin from Community Apps
2. Add new stack: `/mnt/user/appdata/k3s-agents`
3. Click "Deploy Stack"

#### Option B: Via Command Line

```bash
# On Unraid
cd /mnt/user/appdata/k3s-agents/

# Pull images first (optional)
docker-compose pull

# Start agents
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f k3s-agent-1
```

### Step 6: Verify Cluster

From your dev machine:

```bash
# Check all nodes
kubectl get nodes

# You should see:
# NAME          STATUS   ROLES                  AGE   VERSION
# k3s-server    Ready    control-plane,master   5m    v1.28.5+k3s1
# k3s-agent-1   Ready    <none>                 1m    v1.28.5+k3s1
# k3s-agent-2   Ready    <none>                 1m    v1.28.5+k3s1
# k3s-agent-3   Ready    <none>                 1m    v1.28.5+k3s1

# Check node details
kubectl get nodes -o wide

# Label the nodes
kubectl label node k3s-agent-1 node-role.kubernetes.io/worker=worker
kubectl label node k3s-agent-2 node-role.kubernetes.io/worker=worker
kubectl label node k3s-agent-3 node-role.kubernetes.io/worker=worker
```

### Step 7: Deploy ArgoCD and CI/CD Platform

Now run the bootstrap script:

```bash
cd /opt/development/monger-homelab
./scripts/bootstrap-cicd.sh
```

This will install:
- ✅ ArgoCD
- ✅ Tekton
- ✅ External Secrets Operator
- ✅ Custom tasks and pipelines

---

## Resource Usage

### Expected Resource Allocation

| Location | Component | RAM | CPU |
|----------|-----------|-----|-----|
| **Proxmox pve2** | K3s server | 2GB | 2 cores |
| **Unraid** | k3s-agent-1 | 4GB | ~2 cores |
| **Unraid** | k3s-agent-2 | 4GB | ~2 cores |
| **Unraid** | k3s-agent-3 | 4GB | ~2 cores |
| **Total** | | **14GB** | **8 cores** |

### Unraid Impact
- Using: 12GB of 60.6GB available (20%)
- CPU: Minimal (agents mostly idle until workloads deployed)
- Storage: ~5GB on array

### Proxmox Impact
- Using: 2GB of 3.4GB available on pve2
- CPU: 2 of 16 cores
- Storage: 20GB

---

## Troubleshooting

### Agents Won't Connect

**Check connectivity:**
```bash
# From Unraid
ping k3s-server.klsll.com
curl -k https://k3s-server.klsll.com:6443
```

**Check token:**
```bash
# Verify token matches on both sides
ssh james@k3s-server "sudo cat /var/lib/rancher/k3s/server/node-token"
cat /mnt/user/appdata/k3s-agents/.env
```

**Check agent logs:**
```bash
cd /mnt/user/appdata/k3s-agents
docker-compose logs k3s-agent-1
```

### Nodes Show as NotReady

```bash
# Check node status
kubectl describe node k3s-agent-1

# Common issues:
# - Network plugin not ready
# - DNS not working
# - System resources exhausted
```

### DNS Resolution Issues

If k3s-server.klsll.com doesn't resolve:

1. Add to Unraid /etc/hosts:
```bash
echo "192.168.20.XXX k3s-server.klsll.com" >> /etc/hosts
```

2. Or use direct IP in docker-compose.yml:
```yaml
environment:
  - K3S_URL=https://192.168.20.XXX:6443
```

### Restarting Agents

```bash
cd /mnt/user/appdata/k3s-agents

# Restart all
docker-compose restart

# Restart specific agent
docker-compose restart k3s-agent-1

# Full recreate
docker-compose down
docker-compose up -d
```

---

## Monitoring

### Check Agent Health

```bash
# From Unraid
docker stats k3s-agent-1 k3s-agent-2 k3s-agent-3

# Check resource usage over time
docker-compose top
```

### From Kubernetes

```bash
# Node resource usage
kubectl top nodes

# Pod distribution
kubectl get pods -A -o wide

# Events
kubectl get events -A --sort-by='.lastTimestamp'
```

---

## Scaling

### Add More Agents

To add a 4th agent:

1. Edit docker-compose.yml
2. Add k3s-agent-4 section
3. Run: `docker-compose up -d`

### Remove Agents

```bash
# Drain node first
kubectl drain k3s-agent-3 --ignore-daemonsets --delete-emptydir-data

# Delete from cluster
kubectl delete node k3s-agent-3

# Stop container
docker-compose stop k3s-agent-3
docker-compose rm k3s-agent-3
```

---

## Backup & Recovery

### Backup Server

```bash
# On K3s server
sudo systemctl stop k3s
sudo tar czf /tmp/k3s-server-backup.tar.gz /var/lib/rancher/k3s/server
sudo systemctl start k3s
```

### Backup Agents

```bash
# On Unraid
cd /mnt/user/appdata/k3s-agents
tar czf k3s-agents-backup-$(date +%Y%m%d).tar.gz agent-*
```

---

## Next Steps

After your cluster is running:

1. ✅ **Install ArgoCD**: `./scripts/bootstrap-cicd.sh`
2. ✅ **Deploy monitoring**: `kubectl apply -f argocd/applications/monitoring-stack.yaml`
3. ✅ **Configure ESO**: Follow `docs/1PASSWORD_ESO_INTEGRATION.md`
4. ✅ **Deploy first app**: Test with a simple workload

---

**Your hybrid cluster is now ready for enterprise GitOps!** 🚀
