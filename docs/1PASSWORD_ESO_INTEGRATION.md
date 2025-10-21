# 1Password + External Secrets Operator Integration

## Overview

This guide integrates your existing 1Password secret management with Kubernetes using External Secrets Operator (ESO). This creates a unified secret management strategy across:

- **Terraform** - Uses 1Password provider directly
- **Ansible** - Uses Ansible Vault synced from 1Password
- **Kubernetes** - Uses ESO to sync secrets from 1Password

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│               1Password (homelab vault)                  │
│  • Proxmox Terraform credentials                         │
│  • Technitium DNS1/DNS2 API tokens                       │
│  • VM default passwords                                  │
│  • SSH keys                                              │
│  • Ansible Vault password                                │
└───────────────┬─────────────────────────────────────────┘
                │
        ┌───────┴────────┬────────────────┐
        │                │                │
        ▼                ▼                ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐
│  Terraform  │  │   Ansible   │  │  Kubernetes (ESO)   │
│             │  │             │  │                     │
│  Uses       │  │  Vault      │  │  External Secrets   │
│  1Password  │  │  synced     │  │  synced from        │
│  provider   │  │  via script │  │  1Password          │
└─────────────┘  └─────────────┘  └─────────────────────┘
```

## Current 1Password Setup

### Terraform Integration

Your Terraform already uses 1Password via `terraform/1password.tf`:

```hcl
data "onepassword_item" "technitium_dns1" {
  vault = "homelab"
  title = "Technitium DNS1 API"
}

data "onepassword_item" "proxmox" {
  vault = "homelab"
  title = "Proxmox Terraform"
}

# Exported as locals for use
locals {
  dns1_api_token       = data.onepassword_item.technitium_dns1.credential
  proxmox_token_secret = data.onepassword_item.proxmox.credential
  vm_password          = data.onepassword_item.vm_default.password
  ssh_public_key       = data.onepassword_item.ssh_key.public_key
}
```

**Usage**:
```bash
# Set service account token
export OP_SERVICE_ACCOUNT_TOKEN="your-token-here"

# Run terraform
cd terraform
terraform plan
terraform apply
```

### Ansible Integration

Your Ansible uses vault synced from 1Password via `scripts/sync_secrets_from_1password_v2.sh`:

**Configuration**: `config/secrets_mapping.yml`

**Usage**:
```bash
# Sync secrets from 1Password
./scripts/sync_secrets_from_1password_v2.sh

# Run playbooks with vault
ansible-playbook -i inventory/raclette/inventory.ini \
  playbook/technitium_api_backup.yml \
  --vault-password-file ~/.vault_pass
```

## Kubernetes Integration with ESO

### Step 1: Install External Secrets Operator

Already included in the CI/CD setup (`docs/IMPLEMENTATION_GUIDE.md`):

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace
```

### Step 2: Create 1Password Service Account

You likely already have one for Terraform. If not:

1. Go to 1Password → Integrations → Service Accounts
2. Create new service account: `k8s-external-secrets`
3. Grant access to `homelab` vault
4. Save the token securely

### Step 3: Store Service Account Token in Kubernetes

```bash
# Create namespace
kubectl create namespace external-secrets-system

# Store 1Password service account token
kubectl create secret generic onepassword-token \
  -n external-secrets-system \
  --from-literal=token='<your-1password-service-account-token>'
```

### Step 4: Create SecretStore

Create the file `k8s/base/external-secrets/onepassword-secretstore.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: onepassword
  namespace: external-secrets-system
spec:
  provider:
    onepassword:
      # Connect account using service account token
      auth:
        secretRef:
          connectTokenSecretRef:
            name: onepassword-token
            key: token
      
      # Your 1Password vault
      vaults:
        homelab: 1
```

Apply it:
```bash
kubectl apply -f k8s/base/external-secrets/onepassword-secretstore.yaml
```

### Step 5: Create ExternalSecret Resources

#### Example 1: Technitium DNS Credentials

Create `k8s/base/external-secrets/technitium-dns-secrets.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: technitium-dns-credentials
  namespace: dns-system
spec:
  refreshInterval: 1h
  
  secretStoreRef:
    name: onepassword
    kind: SecretStore
  
  target:
    name: technitium-dns-creds
    creationPolicy: Owner
  
  data:
    # DNS1 API Token
    - secretKey: dns1-api-token
      remoteRef:
        key: Technitium DNS1 API
        property: credential
    
    # DNS2 API Token
    - secretKey: dns2-api-token
      remoteRef:
        key: Technitium DNS2 API
        property: credential
```

#### Example 2: Proxmox Credentials for Tekton

Create `k8s/base/external-secrets/proxmox-credentials.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: proxmox-credentials
  namespace: tekton-pipelines
spec:
  refreshInterval: 1h
  
  secretStoreRef:
    name: onepassword
    kind: SecretStore
  
  target:
    name: proxmox-creds
    creationPolicy: Owner
  
  data:
    - secretKey: api-token
      remoteRef:
        key: Proxmox Terraform
        property: credential
    
    - secretKey: vm-password
      remoteRef:
        key: Homelab VM Default
        property: password
```

#### Example 3: SSH Key for Automation

Create `k8s/base/external-secrets/ssh-credentials.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: infrastructure-ssh-key
  namespace: tekton-pipelines
spec:
  refreshInterval: 1h
  
  secretStoreRef:
    name: onepassword
    kind: SecretStore
  
  target:
    name: infrastructure-ssh
    creationPolicy: Owner
  
  data:
    - secretKey: ssh-publickey
      remoteRef:
        key: Spraycheese Infrastructure SSH Key
        property: public key
    
    - secretKey: ssh-privatekey
      remoteRef:
        key: Spraycheese Infrastructure SSH Key
        property: private key
```

### Step 6: Deploy ExternalSecrets

```bash
# Create namespace
kubectl create namespace dns-system

# Apply all ExternalSecret resources
kubectl apply -f k8s/base/external-secrets/

# Verify secrets are synced
kubectl get externalsecrets -A
kubectl get secrets -n dns-system
kubectl get secrets -n tekton-pipelines
```

### Step 7: Use Secrets in Applications

#### In Tekton Pipelines

Reference the synced secret in your pipeline:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: infrastructure-apply
spec:
  tasks:
    - name: terraform-apply
      taskRef:
        name: terraform-apply
      params:
        - name: proxmox-api-token
          value:
            secretKeyRef:
              name: proxmox-creds
              key: api-token
```

#### In ArgoCD Applications

Reference secrets in your application manifests:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dns-controller
spec:
  template:
    spec:
      containers:
        - name: controller
          env:
            - name: DNS1_API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: technitium-dns-creds
                  key: dns1-api-token
```

## Mapping Your Existing Secrets

Based on your 1Password setup, here's the mapping:

| 1Password Item | Field | Kubernetes Secret | Use Case |
|----------------|-------|-------------------|----------|
| **Technitium DNS1 API** | credential | technitium-dns-creds/dns1-api-token | DNS automation |
| **Technitium DNS2 API** | credential | technitium-dns-creds/dns2-api-token | DNS automation |
| **Proxmox Terraform** | credential | proxmox-creds/api-token | Terraform pipelines |
| **Homelab VM Default** | password | proxmox-creds/vm-password | VM provisioning |
| **Spraycheese Infrastructure SSH Key** | public key | infrastructure-ssh/ssh-publickey | SSH access |
| **Spraycheese Infrastructure SSH Key** | private key | infrastructure-ssh/ssh-privatekey | Ansible automation |

## ClusterSecretStore (Advanced)

For secrets used across multiple namespaces, create a ClusterSecretStore:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: onepassword-cluster
spec:
  provider:
    onepassword:
      auth:
        secretRef:
          connectTokenSecretRef:
            name: onepassword-token
            namespace: external-secrets-system
            key: token
      vaults:
        homelab: 1
```

Then reference it in ExternalSecrets:

```yaml
spec:
  secretStoreRef:
    name: onepassword-cluster
    kind: ClusterSecretStore
```

## Monitoring and Troubleshooting

### Check ESO Status

```bash
# Check ESO pods
kubectl get pods -n external-secrets-system

# Check SecretStore status
kubectl get secretstore -A
kubectl describe secretstore onepassword -n external-secrets-system

# Check ExternalSecret status
kubectl get externalsecrets -A
kubectl describe externalsecret technitium-dns-credentials -n dns-system
```

### View Secret Sync Logs

```bash
# ESO controller logs
kubectl logs -n external-secrets-system \
  -l app.kubernetes.io/name=external-secrets

# Check if secret was created
kubectl get secret technitium-dns-creds -n dns-system -o yaml
```

### Common Issues

#### Secret Not Syncing

```bash
# Check ExternalSecret status
kubectl describe externalsecret <name> -n <namespace>

# Common issues:
# - Wrong 1Password item name
# - Wrong field name
# - Token doesn't have access to vault
# - SecretStore not found
```

#### Invalid Token

```bash
# Update the token secret
kubectl delete secret onepassword-token -n external-secrets-system
kubectl create secret generic onepassword-token \
  -n external-secrets-system \
  --from-literal=token='<new-token>'

# Restart ESO
kubectl rollout restart deployment external-secrets -n external-secrets-system
```

## Security Best Practices

### 1. Service Account Tokens

✅ **Do**:
- Use separate service accounts for different purposes
- Terraform: One service account
- Kubernetes: Separate service account
- Rotate tokens periodically

❌ **Don't**:
- Share service account tokens
- Commit tokens to Git
- Use human user accounts

### 2. Kubernetes Secrets

✅ **Do**:
- Use RBAC to restrict access to secrets
- Enable encryption at rest for etcd
- Audit secret access

### 3. Rotation

Set up automatic rotation:

```yaml
spec:
  refreshInterval: 1h  # Check 1Password every hour
  
  # Optionally set up rotation
  target:
    name: my-secret
    creationPolicy: Owner
    deletionPolicy: Retain
```

## Integration with ArgoCD

Add ExternalSecrets to ArgoCD for GitOps:

Create `argocd/applications/external-secrets.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets-config
  namespace: argocd
spec:
  project: infrastructure
  
  source:
    repoURL: https://github.com/HavartiBard/monger-homelab.git
    targetRevision: main
    path: k8s/base/external-secrets
  
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets-system
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Complete Setup Checklist

- [ ] Install External Secrets Operator
- [ ] Create 1Password service account for K8s
- [ ] Store service account token in K8s secret
- [ ] Create SecretStore resource
- [ ] Create ExternalSecret resources for each secret needed
- [ ] Verify secrets are syncing
- [ ] Update applications to use synced secrets
- [ ] Add to ArgoCD for GitOps management
- [ ] Document secret rotation procedures
- [ ] Set up monitoring/alerts for sync failures

## Next Steps

1. **Deploy ESO** - Follow Phase 3 in `docs/IMPLEMENTATION_GUIDE.md`
2. **Create ExternalSecrets** - Use the examples above
3. **Update Tekton Pipelines** - Reference K8s secrets instead of env vars
4. **Test Secret Sync** - Verify secrets are available
5. **Add to GitOps** - Manage via ArgoCD

---

**Created**: 2025-10-21  
**Integration**: 1Password + External Secrets Operator  
**Status**: Ready for Implementation
