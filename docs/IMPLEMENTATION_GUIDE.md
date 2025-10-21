# CI/CD Implementation Guide - Step by Step

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] K3s cluster deployed (3 control plane, 3+ worker nodes)
- [ ] `kubectl` configured to access your cluster
- [ ] Helm 3 installed on your development machine
- [ ] Git repository access (GitHub/GitLab)
- [ ] Proxmox cluster healthy and accessible

## Phase 1: Deploy K3s Cluster (If Not Already Done)

### Step 1.1: Deploy K3s VMs via Terraform

```bash
cd /opt/development/monger-homelab/terraform

# Review the K3s configuration
cat k3s.tfvars

# Initialize Terraform (if not already done)
terraform init

# Plan the deployment
terraform plan -var-file=k3s.tfvars -out=k3s.plan

# Apply the plan
terraform apply k3s.plan
```

Expected output:
- 3 control plane VMs: `k3s-controller-1`, `k3s-controller-2`, `k3s-controller-3`
- 4 worker VMs: `k3s-worker-1` through `k3s-worker-4`

### Step 1.2: Install K3s Using k3s-ansible

```bash
cd /opt/development/monger-homelab

# Check if k3s-ansible submodule exists
ls -la k3s-ansible/

# If empty, initialize it
git submodule update --init --recursive

# Or clone directly
git clone https://github.com/k3s-io/k3s-ansible.git

cd k3s-ansible

# Create inventory for your cluster
cat > inventory/homelab/hosts.ini << EOF
[master]
k3s-controller-1 ansible_host=192.168.20.110 ansible_user=james
k3s-controller-2 ansible_host=192.168.20.111 ansible_user=james
k3s-controller-3 ansible_host=192.168.20.112 ansible_user=james

[node]
k3s-worker-1 ansible_host=192.168.20.120 ansible_user=james
k3s-worker-2 ansible_host=192.168.20.121 ansible_user=james
k3s-worker-3 ansible_host=192.168.20.122 ansible_user=james
k3s-worker-4 ansible_host=192.168.20.123 ansible_user=james

[k3s_cluster:children]
master
node
EOF

# Configure K3s settings
cat > inventory/homelab/group_vars/all.yml << EOF
---
k3s_version: v1.28.5+k3s1
ansible_user: james
systemd_dir: /etc/systemd/system

# Cluster configuration
k3s_server:
  cluster-init: true
  disable:
    - traefik  # We'll use ingress-nginx
  write-kubeconfig-mode: 644
  kube-apiserver-arg:
    - "anonymous-auth=false"

# High availability
k3s_control_node: true
k3s_server_location: /var/lib/rancher/k3s
EOF

# Deploy K3s
ansible-playbook site.yml -i inventory/homelab/hosts.ini

# Copy kubeconfig from master node
scp james@192.168.20.110:~/.kube/config ~/.kube/config-homelab

# Set KUBECONFIG
export KUBECONFIG=~/.kube/config-homelab

# Verify cluster
kubectl get nodes
```

Expected output:
```
NAME                STATUS   ROLES                       AGE   VERSION
k3s-controller-1    Ready    control-plane,etcd,master   5m    v1.28.5+k3s1
k3s-controller-2    Ready    control-plane,etcd,master   4m    v1.28.5+k3s1
k3s-controller-3    Ready    control-plane,etcd,master   4m    v1.28.5+k3s1
k3s-worker-1        Ready    <none>                      3m    v1.28.5+k3s1
k3s-worker-2        Ready    <none>                      3m    v1.28.5+k3s1
k3s-worker-3        Ready    <none>                      3m    v1.28.5+k3s1
k3s-worker-4        Ready    <none>                      3m    v1.28.5+k3s1
```

---

## Phase 2: Install ArgoCD

### Step 2.1: Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access ArgoCD UI: https://localhost:8080
# Username: admin
# Password: (from above command)
```

### Step 2.2: Install ArgoCD CLI

```bash
# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Verify installation
argocd version

# Login via CLI
argocd login localhost:8080 --username admin --password <password> --insecure
```

### Step 2.3: Configure ArgoCD for Your Repository

```bash
# Add your Git repository
argocd repo add https://github.com/HavartiBard/monger-homelab.git

# Verify repository
argocd repo list
```

### Step 2.4: Deploy Infrastructure Project

```bash
cd /opt/development/monger-homelab

# Apply the infrastructure project
kubectl apply -f argocd/projects/infrastructure.yaml

# Verify project creation
argocd proj list
```

### Step 2.5: Deploy App of Apps

```bash
# Deploy the root application
kubectl apply -f argocd/applications/argocd-apps.yaml

# Watch applications sync
argocd app list

# Check sync status
argocd app get argocd-apps
```

---

## Phase 3: Install Tekton

### Step 3.1: Install Tekton Pipelines

```bash
# Install Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Wait for installation
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=tekton-pipelines -n tekton-pipelines --timeout=300s

# Verify installation
kubectl get pods -n tekton-pipelines
```

### Step 3.2: Install Tekton Triggers

```bash
# Install Tekton Triggers (for webhook integration)
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml

# Verify installation
kubectl get pods -n tekton-pipelines
```

### Step 3.3: Install Tekton Dashboard (Optional)

```bash
# Install Tekton Dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml

# Port forward to access dashboard
kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097

# Access: http://localhost:9097
```

### Step 3.4: Install Tekton CLI (tkn)

```bash
# Linux
curl -LO https://github.com/tektoncd/cli/releases/download/v0.33.0/tkn_0.33.0_Linux_x86_64.tar.gz
tar xvzf tkn_0.33.0_Linux_x86_64.tar.gz tkn
sudo mv tkn /usr/local/bin/

# Verify installation
tkn version
```

---

## Phase 4: Deploy Tasks and Pipelines

### Step 4.1: Deploy Tekton Tasks

```bash
cd /opt/development/monger-homelab

# Deploy custom tasks
kubectl apply -f tekton/tasks/

# Verify tasks
tkn task list -n tekton-pipelines
```

### Step 4.2: Install Git Clone Task (from Tekton Catalog)

```bash
# Install the git-clone task from Tekton Hub
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml

# Verify
tkn task list -n tekton-pipelines
```

### Step 4.3: Deploy Infrastructure Validation Pipeline

```bash
# Deploy the pipeline
kubectl apply -f tekton/pipelines/infrastructure-validation.yaml

# Verify pipeline
tkn pipeline list -n tekton-pipelines
```

### Step 4.4: Test the Pipeline

```bash
# Create a test PipelineRun
tkn pipeline start infrastructure-validation \
  -n tekton-pipelines \
  --param git-url=https://github.com/HavartiBard/monger-homelab.git \
  --param git-revision=main \
  --workspace name=shared-data,volumeClaimTemplateFile=- \
  --showlog

# Or use the PipelineRun from the YAML
kubectl create -f tekton/pipelines/infrastructure-validation.yaml

# Watch the pipeline run
tkn pipelinerun logs -f -n tekton-pipelines
```

---

## Phase 5: Install External Secrets Operator

### Step 5.1: Install via Helm

```bash
# Add helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install External Secrets Operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace

# Verify installation
kubectl get pods -n external-secrets-system
```

### Step 5.2: Configure Secret Store (Example: Bitwarden)

```bash
# Create a secret with Bitwarden credentials
kubectl create secret generic bitwarden-credentials \
  -n external-secrets-system \
  --from-literal=BW_PASSWORD='your-password'

# Create SecretStore
cat > /tmp/secret-store.yaml << EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: bitwarden-store
  namespace: external-secrets-system
spec:
  provider:
    webhook:
      url: "http://bitwarden-cli-service:8087/object/{{ .remoteRef.key }}"
      result:
        jsonPath: "$.data.password"
EOF

kubectl apply -f /tmp/secret-store.yaml
```

---

## Phase 6: Deploy Monitoring Stack

### Step 6.1: Deploy via ArgoCD

The monitoring stack will be automatically deployed by ArgoCD if you've applied the app-of-apps pattern.

```bash
# Check if monitoring application is synced
argocd app get monitoring-stack

# Manually sync if needed
argocd app sync monitoring-stack

# Watch deployment
kubectl get pods -n monitoring -w
```

### Step 6.2: Access Grafana

```bash
# Get Grafana password
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d && echo

# Port forward
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Access: http://localhost:3000
# Username: admin
# Password: (from above)
```

### Step 6.3: Access Prometheus

```bash
# Port forward
kubectl port-forward -n monitoring svc/monitoring-prometheus 9090:9090

# Access: http://localhost:9090
```

---

## Phase 7: Configure GitHub Webhooks (Optional)

### Step 7.1: Create EventListener for GitHub Webhooks

```bash
cd /opt/development/monger-homelab

# Create EventListener, TriggerBinding, and TriggerTemplate
cat > tekton/triggers/github-webhook.yaml << EOF
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-listener
  namespace: tekton-pipelines
spec:
  serviceAccountName: tekton-triggers-sa
  triggers:
    - name: github-push-trigger
      interceptors:
        - ref:
            name: "github"
          params:
            - name: "secretRef"
              value:
                secretName: github-webhook-secret
                secretKey: webhook-secret
            - name: "eventTypes"
              value: ["push"]
      bindings:
        - ref: github-push-binding
      template:
        ref: infrastructure-validation-template
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: github-push-binding
  namespace: tekton-pipelines
spec:
  params:
    - name: git-url
      value: \$(body.repository.clone_url)
    - name: git-revision
      value: \$(body.ref)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: infrastructure-validation-template
  namespace: tekton-pipelines
spec:
  params:
    - name: git-url
    - name: git-revision
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: infrastructure-validation-
      spec:
        pipelineRef:
          name: infrastructure-validation
        params:
          - name: git-url
            value: \$(tt.params.git-url)
          - name: git-revision
            value: \$(tt.params.git-revision)
        workspaces:
          - name: shared-data
            volumeClaimTemplate:
              spec:
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: 1Gi
EOF

kubectl apply -f tekton/triggers/github-webhook.yaml
```

### Step 7.2: Expose EventListener

```bash
# Create Ingress or use port-forward for testing
kubectl port-forward -n tekton-pipelines svc/el-github-listener 8090:8080

# Your webhook URL: http://your-public-ip:8090
```

### Step 7.3: Configure GitHub Webhook

1. Go to your GitHub repository settings
2. Navigate to Webhooks → Add webhook
3. Payload URL: `http://your-public-ip:8090`
4. Content type: `application/json`
5. Secret: (create a random string)
6. Events: Select "Just the push event"
7. Active: ✅

---

## Phase 8: Verification and Testing

### Step 8.1: Verify All Components

```bash
# Check all namespaces
kubectl get ns

# Check ArgoCD applications
argocd app list

# Check Tekton resources
tkn pipeline list -n tekton-pipelines
tkn task list -n tekton-pipelines

# Check monitoring
kubectl get pods -n monitoring
```

### Step 8.2: Test End-to-End Flow

```bash
# Make a change to your repository
cd /opt/development/monger-homelab
echo "# Test change" >> README.md
git add README.md
git commit -m "test: trigger pipeline"
git push origin main

# Watch pipeline execution
tkn pipelinerun logs -f -n tekton-pipelines

# Or via Tekton Dashboard
# http://localhost:9097
```

### Step 8.3: Test Ansible Deployment

```bash
# Create a test change to DNS config
vim config/dns_zones.yml
# Add a test record

# Commit and push
git add config/dns_zones.yml
git commit -m "feat: add test DNS record"
git push origin main

# Watch ArgoCD sync (if configured) or trigger manually
```

---

## Troubleshooting

### ArgoCD Not Syncing

```bash
# Check application status
argocd app get <app-name>

# Force sync
argocd app sync <app-name> --force

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Tekton Pipeline Failing

```bash
# Check pipeline run status
tkn pipelinerun describe <pipelinerun-name> -n tekton-pipelines

# Check logs
tkn pipelinerun logs <pipelinerun-name> -n tekton-pipelines

# Check pod status
kubectl get pods -n tekton-pipelines | grep <pipelinerun-name>
kubectl logs -n tekton-pipelines <pod-name>
```

### Monitoring Not Working

```bash
# Check pods
kubectl get pods -n monitoring

# Check logs
kubectl logs -n monitoring <pod-name>

# Check services
kubectl get svc -n monitoring
```

---

## Maintenance

### Updating ArgoCD

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Updating Tekton

```bash
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
```

### Backup ArgoCD Configuration

```bash
# Export all applications
argocd app list -o yaml > argocd-apps-backup.yaml

# Export all projects
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml
```

---

## Next Steps After Implementation

1. **Configure notifications** - Set up Slack/Discord webhooks
2. **Add more pipelines** - DNS deployment, Ansible execution
3. **Implement RBAC** - Fine-tune access control
4. **Add testing** - Integration tests, smoke tests
5. **Document runbooks** - Incident response procedures
6. **Set up backups** - Automated backup verification

---

**Last Updated**: 2025-10-21  
**Maintained By**: Infrastructure Team
