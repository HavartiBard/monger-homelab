# Resource-Constrained Deployment Options

## Check Your Current Resources

Run these commands on each Proxmox node to check available resources:

### On pve1 and pve2 (via SSH or web shell):

```bash
# CPU cores and usage
echo "=== CPU ==="
nproc
top -bn1 | grep "Cpu(s)"

# Memory (in GB)
echo "=== Memory ==="
free -h

# Storage
echo "=== Storage ==="
pvesm status
df -h

# Current VMs/Containers
echo "=== VMs ==="
qm list

echo "=== Containers ==="
pct list
```

Copy the output and we can determine the best deployment strategy.

---

## Deployment Options (From Most to Least Resource-Intensive)

### Option 1: Full Production Cluster ⭐ (If You Have 36GB+ RAM Available)

**Original Plan - Best for enterprise simulation**

| Component | VMs | RAM | vCPU | Storage |
|-----------|-----|-----|------|---------|
| Control Plane | 3 | 12GB | 6 | 30GB |
| Workers | 4 | 16GB | 8 | 100GB |
| Overhead | - | 8GB | 4 | 20GB |
| **Total** | **7** | **36GB** | **18** | **150GB** |

**Pros:**
- ✅ True HA with 3 control plane nodes
- ✅ Plenty of worker capacity
- ✅ Can run all services (monitoring, CI/CD, apps)
- ✅ Enterprise-grade setup

**Cons:**
- ❌ Requires significant resources
- ❌ May be overkill for homelab

**Deploy with:**
```bash
cd terraform
terraform apply -var-file=k3s.auto.tfvars
```

---

### Option 2: Minimal Production Cluster 🎯 (12-16GB RAM Available)

**Recommended for most homelabs**

| Component | VMs | RAM | vCPU | Storage |
|-----------|-----|-----|------|---------|
| Control Plane | 1 | 4GB | 2 | 20GB |
| Workers | 2-3 | 8-12GB | 4-6 | 60-100GB |
| **Total** | **3-4** | **12-16GB** | **6-8** | **80-120GB** |

**Pros:**
- ✅ Production-capable
- ✅ Runs all essential services
- ✅ Can scale up later
- ✅ Much more resource-friendly

**Cons:**
- ⚠️ Single point of failure (1 control plane)
- ⚠️ Less worker capacity

**Create minimal tfvars:**
```hcl
# k3s-minimal.auto.tfvars
vms = [
  {
    name        = "k3s-controller-1"
    desc        = "K3s Control Plane"
    target_node = "pve1"
    ip          = "dhcp"
    memory      = 4096
    cores       = 2
    disk_size   = "20G"
    tags        = "k3s,controller"
  },
  {
    name        = "k3s-worker-1"
    desc        = "K3s Worker 1"
    target_node = "pve1"
    ip          = "dhcp"
    memory      = 4096
    cores       = 2
    disk_size   = "40G"
    tags        = "k3s,worker"
  },
  {
    name        = "k3s-worker-2"
    desc        = "K3s Worker 2"
    target_node = "pve2"
    ip          = "dhcp"
    memory      = 4096
    cores       = 2
    disk_size   = "40G"
    tags        = "k3s,worker"
  }
]
```

**Deploy with:**
```bash
cd terraform
terraform apply -var-file=k3s-minimal.auto.tfvars
```

---

### Option 3: Hybrid Proxmox + Unraid 🌟 (4-8GB RAM on Proxmox)

**Best balance of resources and capability**

**On Proxmox:**
- 1 K3s server VM: 4GB RAM, 2 cores, 20GB storage

**On Unraid (Docker containers):**
- 2-3 K3s agent containers
- Each: 2GB RAM, 2 cores

**Total Proxmox Need:** 4GB RAM, 2 cores, 20GB storage

**Pros:**
- ✅ Minimal Proxmox footprint
- ✅ Leverages Unraid compute
- ✅ K3s officially supports mixed clusters
- ✅ Scalable (add more Unraid agents easily)

**Cons:**
- ⚠️ Slightly more complex setup
- ⚠️ Requires Unraid Docker configuration

#### Proxmox Component:

Create `k3s-hybrid.auto.tfvars`:
```hcl
vms = [
  {
    name        = "k3s-server"
    desc        = "K3s Server (Control Plane)"
    target_node = "pve1"
    ip          = "dhcp"
    memory      = 4096
    cores       = 2
    disk_size   = "20G"
    tags        = "k3s,server"
  }
]
```

#### Unraid Component (Docker Compose):

Create on Unraid at `/mnt/user/appdata/k3s-agent/docker-compose.yml`:

```yaml
version: '3.8'

services:
  k3s-agent-1:
    image: rancher/k3s:v1.28.5-k3s1
    container_name: k3s-agent-1
    privileged: true
    restart: unless-stopped
    environment:
      - K3S_URL=https://k3s-server.klsll.com:6443  # Your Proxmox K3s server
      - K3S_TOKEN=${K3S_TOKEN}  # Get from server: cat /var/lib/rancher/k3s/server/node-token
    volumes:
      - /var/lib/rancher/k3s-agent-1:/var/lib/rancher/k3s
    networks:
      - host
    labels:
      - "node.role=worker"
  
  k3s-agent-2:
    image: rancher/k3s:v1.28.5-k3s1
    container_name: k3s-agent-2
    privileged: true
    restart: unless-stopped
    environment:
      - K3S_URL=https://k3s-server.klsll.com:6443
      - K3S_TOKEN=${K3S_TOKEN}
    volumes:
      - /var/lib/rancher/k3s-agent-2:/var/lib/rancher/k3s
    networks:
      - host
    labels:
      - "node.role=worker"

networks:
  host:
    external: true
    name: host
```

**Setup Steps:**
1. Deploy K3s server on Proxmox
2. Get token: `ssh james@k3s-server "sudo cat /var/lib/rancher/k3s/server/node-token"`
3. Create `.env` file on Unraid with token
4. Run `docker-compose up -d`
5. Verify: `kubectl get nodes`

---

### Option 4: K3s Entirely on Unraid 🐳 (0GB RAM on Proxmox)

**Maximum resource conservation**

Run everything on Unraid using Docker containers.

**Proxmox Need:** None

**Pros:**
- ✅ Zero Proxmox resources used
- ✅ Fast deployment
- ✅ Easy to tear down/rebuild
- ✅ Good for testing

**Cons:**
- ❌ Less enterprise-like
- ❌ No VM isolation
- ❌ May have networking complexity

#### Docker Compose on Unraid:

`/mnt/user/appdata/k3s/docker-compose.yml`:

```yaml
version: '3.8'

services:
  k3s-server:
    image: rancher/k3s:v1.28.5-k3s1
    container_name: k3s-server
    privileged: true
    restart: unless-stopped
    command: server
    environment:
      - K3S_KUBECONFIG_OUTPUT=/output/kubeconfig.yaml
      - K3S_KUBECONFIG_MODE=666
    volumes:
      - k3s-server:/var/lib/rancher/k3s
      - ./kubeconfig:/output
    ports:
      - "6443:6443"  # Kubernetes API
      - "8080:8080"  # ArgoCD (via NodePort)
    networks:
      - k3s-net
  
  k3s-agent-1:
    image: rancher/k3s:v1.28.5-k3s1
    container_name: k3s-agent-1
    privileged: true
    restart: unless-stopped
    command: agent
    environment:
      - K3S_URL=https://k3s-server:6443
      - K3S_TOKEN_FILE=/var/lib/rancher/k3s/server/node-token
    volumes:
      - k3s-agent-1:/var/lib/rancher/k3s
    depends_on:
      - k3s-server
    networks:
      - k3s-net
  
  k3s-agent-2:
    image: rancher/k3s:v1.28.5-k3s1
    container_name: k3s-agent-2
    privileged: true
    restart: unless-stopped
    command: agent
    environment:
      - K3S_URL=https://k3s-server:6443
      - K3S_TOKEN_FILE=/var/lib/rancher/k3s/server/node-token
    volumes:
      - k3s-agent-2:/var/lib/rancher/k3s
    depends_on:
      - k3s-server
    networks:
      - k3s-net

volumes:
  k3s-server:
  k3s-agent-1:
  k3s-agent-2:

networks:
  k3s-net:
    driver: bridge
```

**Deploy:**
```bash
# On Unraid
cd /mnt/user/appdata/k3s
docker-compose up -d

# Get kubeconfig
cp kubeconfig/kubeconfig.yaml ~/.kube/config

# Verify
kubectl get nodes
```

---

### Option 5: Single-Node K3s 💻 (4GB RAM)

**Absolute minimum for testing**

One VM running both server and agent.

**Resources:** 4GB RAM, 2 cores, 20GB storage

**Pros:**
- ✅ Minimal resources
- ✅ Quick to deploy
- ✅ Good for learning/testing

**Cons:**
- ❌ Not HA
- ❌ Limited capacity
- ❌ Single point of failure

```hcl
# k3s-single.auto.tfvars
vms = [
  {
    name        = "k3s-allinone"
    desc        = "K3s All-in-One"
    target_node = "pve1"
    ip          = "dhcp"
    memory      = 4096
    cores       = 2
    disk_size   = "20G"
    tags        = "k3s,server,worker"
  }
]
```

---

## Reduced Service Deployment

Regardless of cluster size, you can reduce what services you deploy:

### Minimal Deployment (Lowest overhead)
- ArgoCD only
- No monitoring initially
- Essential apps only

**RAM Usage:** ~2GB
**CPU Usage:** ~1 core

### Essential Deployment (Recommended)
- ArgoCD
- Basic Prometheus (no long-term storage)
- Grafana
- Loki (log aggregation)

**RAM Usage:** ~4GB
**CPU Usage:** ~2 cores

### Full Deployment
- Everything in the original plan
- Prometheus with Thanos
- Full monitoring stack
- All CI/CD tooling

**RAM Usage:** ~8GB
**CPU Usage:** ~4 cores

---

## Decision Matrix

| Your Available Resources | Recommended Option |
|--------------------------|-------------------|
| **36GB+ RAM, 18+ cores** | Option 1: Full Production |
| **16-24GB RAM, 8-12 cores** | Option 2: Minimal Production |
| **8-16GB RAM, 4-8 cores** | Option 3: Hybrid Proxmox + Unraid |
| **4-8GB RAM, 2-4 cores** | Option 4: K3s on Unraid |
| **Testing only** | Option 5: Single-Node |

---

## Next Steps

1. **Check your resources** - Run the commands above on pve1 and pve2
2. **Share the output** - I'll analyze and recommend the best option
3. **I'll create the tfvars** - Customized for your chosen approach
4. **Deploy** - Follow the updated implementation guide

---

## Scaling Up Later

All options can scale:
- **Option 2**: Add more workers or upgrade to HA control plane
- **Option 3**: Add more Unraid agents or migrate to full Proxmox
- **Option 4**: Migrate to Proxmox VMs when resources available
- **Option 5**: Convert to multi-node cluster

---

**The beauty of K3s:** It's production-capable even in minimal configurations. You can start small and grow!
