# CI/CD Pipeline Strategy for Monger Homelab

## Executive Summary

This document outlines the enterprise-grade CI/CD strategy for the homelab infrastructure, implementing GitOps principles with ArgoCD and Tekton pipelines.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Development Machine                       │
│  • Code changes                                              │
│  • Git push to GitHub                                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  GitHub Repository                           │
│  • Infrastructure as Code                                    │
│  • Ansible playbooks                                         │
│  • Terraform definitions                                     │
│  • K8s manifests                                             │
└──────────────┬────────────────┬─────────────────────────────┘
               │                │
               ▼                ▼
    ┌──────────────────┐  ┌──────────────────┐
    │   Tekton CI      │  │    ArgoCD        │
    │   (Build/Test)   │  │   (Deploy)       │
    └────────┬─────────┘  └────────┬─────────┘
             │                     │
             │ ┌───────────────────┘
             ▼ ▼
┌─────────────────────────────────────────────────────────────┐
│              K3s Cluster on Proxmox                          │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │   ArgoCD       │  │   Tekton       │  │  External    │  │
│  │   (GitOps)     │  │   (CI)         │  │  Secrets     │  │
│  │                │  │                │  │  Operator    │  │
│  └────────────────┘  └────────────────┘  └──────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         Applications & Services                         │ │
│  │  • DNS/DHCP management                                  │ │
│  │  • Monitoring (Prometheus/Grafana)                      │ │
│  │  • Logging (Loki)                                       │ │
│  │  • Home automation                                      │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           Infrastructure (Managed via Ansible)               │
│  • Proxmox VMs                                               │
│  • LXC containers                                            │
│  • DNS/DHCP servers                                          │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Workflows

### Workflow 1: Infrastructure Changes (Terraform/Ansible)

```
Developer Push → GitHub → Tekton Pipeline → Validation → Apply
                                    │
                                    ├── Terraform validate
                                    ├── Terraform plan
                                    ├── Ansible syntax check
                                    ├── YAML lint
                                    └── (Manual approval for prod)
                                              │
                                              ▼
                                        Apply changes
                                              │
                                              ├── Terraform apply
                                              ├── Ansible playbook run
                                              └── Notification (Slack/Discord)
```

### Workflow 2: Kubernetes Application Deployment (GitOps)

```
Developer Push → GitHub → ArgoCD detects change → Sync → Deploy
                              │
                              ├── Compare desired vs actual state
                              ├── Auto-sync (if enabled)
                              └── Health check
                                      │
                                      ▼
                                 Application deployed
                                      │
                                      └── Notification
```

### Workflow 3: DNS/DHCP Configuration Updates

```
Developer Push → GitHub → Tekton Pipeline → Ansible Playbook
    │                                │
    └── config/dns_zones.yml        ├── Validate YAML
    └── config/dhcp_scopes.yml      ├── Run playbook in dry-run
                                     ├── (Manual approval)
                                     └── Deploy to Technitium servers
                                           │
                                           └── Verify DNS resolution
```

## Technology Stack

### Core Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **GitOps Engine** | ArgoCD | Declarative continuous deployment |
| **CI Pipeline** | Tekton | Build, test, validate infrastructure |
| **K8s Distribution** | K3s | Lightweight Kubernetes |
| **IaC** | Terraform | VM/LXC provisioning |
| **Configuration Mgmt** | Ansible | OS configuration, application setup |
| **Secret Management** | External Secrets Operator | Sync secrets from external sources |
| **Monitoring** | Prometheus + Grafana | Metrics and dashboards |
| **Logging** | Loki + Promtail | Centralized logging |
| **Notifications** | Slack/Discord webhooks | Pipeline status updates |

## Implementation Phases

### Phase 1: Foundation (Week 1-2) ⭐ **START HERE**

#### 1.1 Deploy K3s Cluster (if not already deployed)
```bash
cd /opt/development/monger-homelab/terraform
terraform apply -var-file=k3s.tfvars
```

#### 1.2 Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### 1.3 Install Tekton
```bash
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
```

#### 1.4 Setup External Secrets Operator
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

### Phase 2: Pipeline Configuration (Week 2-3)

#### 2.1 Create Repository Structure
```
monger-homelab/
├── .github/
│   └── workflows/               # GitHub Actions (optional, for basic checks)
├── argocd/
│   ├── applications/            # ArgoCD Application manifests
│   └── projects/                # ArgoCD Projects
├── tekton/
│   ├── pipelines/               # Tekton Pipeline definitions
│   ├── tasks/                   # Reusable Tekton Tasks
│   └── triggers/                # EventListeners, TriggerBindings
├── k8s/
│   ├── base/                    # Base K8s manifests
│   └── overlays/                # Kustomize overlays (dev/prod)
├── terraform/                   # Existing
├── playbook/                    # Existing
└── config/                      # Existing
```

#### 2.2 Define Tekton Pipelines
- **infrastructure-validation**: Validate Terraform and Ansible
- **infrastructure-apply**: Apply infrastructure changes
- **dns-config-update**: Update DNS/DHCP configuration
- **app-deploy**: Build and test applications

#### 2.3 Configure ArgoCD Applications
- **monitoring-stack**: Prometheus, Grafana, Loki
- **automation-tools**: n8n, other automation
- **infrastructure-apps**: DNS dashboards, etc.

### Phase 3: Secret Management (Week 3-4)

#### 3.1 Move Secrets Out of Git
- Create secrets in a secure store (Bitwarden, Vault, AWS Secrets Manager)
- Configure External Secrets Operator to sync
- Update Terraform/Ansible to use secrets from K8s

#### 3.2 Secret Rotation
- Implement automated secret rotation for API keys
- Set up alerts for expiring secrets

### Phase 4: Monitoring & Observability (Week 4-5)

#### 4.1 Deploy Monitoring Stack
- Prometheus for metrics
- Grafana for dashboards
- Loki for logs
- Alertmanager for alerts

#### 4.2 Create Dashboards
- Infrastructure health (Proxmox, DNS, DHCP)
- Pipeline metrics (success rate, duration)
- Application metrics

### Phase 5: Advanced Features (Week 6+)

#### 5.1 Multi-Environment Support
- Separate dev/staging/prod environments
- Environment-specific configurations
- Promotion workflows

#### 5.2 Disaster Recovery
- Automated backups of ArgoCD configs
- Cluster restore procedures
- Backup verification testing

## Security Best Practices

### 1. Secret Management
- ✅ Never commit secrets to Git
- ✅ Use External Secrets Operator
- ✅ Rotate secrets regularly
- ✅ Audit secret access

### 2. Access Control
- ✅ Implement RBAC in ArgoCD
- ✅ Use service accounts for pipelines
- ✅ Require approvals for production changes
- ✅ Enable audit logging

### 3. Network Security
- ✅ Isolate K3s cluster network
- ✅ Use network policies
- ✅ Implement ingress authentication
- ✅ Enable TLS everywhere

### 4. Supply Chain Security
- ✅ Sign container images
- ✅ Scan images for vulnerabilities
- ✅ Use specific image tags (not :latest)
- ✅ Verify Terraform module sources

## Pipeline Examples

### Example 1: Terraform Validation Pipeline

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: terraform-validate
spec:
  params:
    - name: git-url
    - name: git-revision
  workspaces:
    - name: shared-data
  tasks:
    - name: fetch-repo
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.git-url)
        - name: revision
          value: $(params.git-revision)
      workspaces:
        - name: output
          workspace: shared-data
    
    - name: terraform-fmt
      taskRef:
        name: terraform-fmt
      runAfter: [fetch-repo]
      workspaces:
        - name: source
          workspace: shared-data
    
    - name: terraform-validate
      taskRef:
        name: terraform-validate
      runAfter: [terraform-fmt]
      workspaces:
        - name: source
          workspace: shared-data
    
    - name: notify-success
      taskRef:
        name: slack-notify
      runAfter: [terraform-validate]
      params:
        - name: message
          value: "✅ Terraform validation passed"
```

### Example 2: ArgoCD Application for DNS Management

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dns-management
  namespace: argocd
spec:
  project: infrastructure
  source:
    repoURL: https://github.com/HavartiBard/monger-homelab.git
    targetRevision: main
    path: k8s/dns-management
  destination:
    server: https://kubernetes.default.svc
    namespace: dns-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

## Cost & Resource Estimates

### K3s Cluster Resources (Minimum)
- **3 control plane nodes**: 3 x 4GB RAM = 12GB
- **3 worker nodes**: 3 x 4GB RAM = 12GB
- **Total**: ~24GB RAM, 12 CPU cores

### Additional Services
- **ArgoCD**: 2GB RAM, 1 CPU
- **Tekton**: 1GB RAM, 0.5 CPU
- **Monitoring Stack**: 4GB RAM, 2 CPU
- **Total overhead**: ~7GB RAM, 3.5 CPU

### Total Cluster Requirements
- **RAM**: 31GB (round up to 32GB minimum)
- **CPU**: 15.5 cores (16 cores recommended)
- **Storage**: 500GB+ (applications, logs, images)

## Migration Strategy

### Current State → Target State

**Current (Manual)**
```
Developer → Git push → Manual terraform apply → Manual ansible-playbook
```

**Target (Automated)**
```
Developer → Git push → Tekton (validate) → ArgoCD (deploy) → Notification
```

### Migration Steps

1. **Week 1**: Deploy K3s cluster alongside existing infrastructure
2. **Week 2**: Install ArgoCD and Tekton, run in observation mode
3. **Week 3**: Migrate non-critical workloads (monitoring, dashboards)
4. **Week 4**: Implement secret management
5. **Week 5**: Migrate critical infrastructure (DNS config updates)
6. **Week 6+**: Decommission manual processes, full GitOps

## Success Metrics

| Metric | Current | Target (3 months) |
|--------|---------|-------------------|
| **Deployment frequency** | Manual (weekly?) | Multiple per day |
| **Lead time** | Hours | Minutes |
| **MTTR** | Hours | <30 minutes |
| **Change failure rate** | Unknown | <5% |
| **Manual steps** | Many | Zero (automated) |

## Rollback Strategy

### Automatic Rollbacks
- ArgoCD can automatically rollback on health check failure
- Keep last 10 revisions in Git history
- Tag stable releases

### Manual Rollback
```bash
# Rollback via ArgoCD
argocd app rollback <app-name> <revision>

# Rollback via Terraform
cd terraform
git checkout <previous-commit>
terraform apply

# Rollback via Ansible
cd playbook
ansible-playbook restore_dns_backup.yml
```

## Disaster Recovery

### Cluster Failure
1. Restore Proxmox VMs from backup
2. Reinstall K3s cluster
3. Restore ArgoCD configuration from Git
4. ArgoCD will automatically restore all applications

### Data Loss
1. DNS/DHCP configs are in Git
2. Backups stored on Unraid NFS
3. Database backups (if applicable) in S3-compatible storage

## Notifications

### Notification Channels
- **Slack/Discord**: Pipeline status, deployments, failures
- **Email**: Critical alerts only
- **PagerDuty** (optional): Production incidents

### Notification Examples
- ✅ Deployment succeeded
- ❌ Pipeline failed
- ⚠️ Manual approval required
- 🔄 Sync in progress
- 🚀 New application version deployed

## Next Steps

### Immediate Actions (This Week)
1. ✅ Review this document
2. ⬜ Verify K3s cluster status (deployed or needs deployment)
3. ⬜ Decide: ArgoCD vs Jenkins (Recommendation: ArgoCD)
4. ⬜ Plan resource allocation on Proxmox
5. ⬜ Schedule Phase 1 implementation

### Questions to Answer
- Is K3s cluster already deployed? (VMs defined in k3s.tfvars)
- What's your preferred notification channel? (Slack/Discord)
- Where do you want to store secrets? (Bitwarden/Vault/cloud)
- Do you want GitLab/GitHub Actions integration?
- Budget for cloud services (if any)?

---

**Created**: 2025-10-21  
**Author**: Senior SRE Team  
**Status**: Draft - Awaiting Review
