# Repository Cleanup Recommendations

## Files to Remove

### Old/Duplicate Scripts
```bash
# Remove old secret sync scripts (replaced by v2)
rm scripts/sync_secrets_from_1password.sh
rm scripts/load_secrets_from_1password.sh

# Keep:
# - scripts/sync_secrets_from_1password_v2.sh (current)
# - scripts/load_terraform_secrets.sh (current)
```

### Duplicate Documentation
```bash
# Remove old secret management docs
rm docs/SECRETS_MANAGEMENT.md
rm docs/SECRETS_MANAGEMENT_SIMPLE.md

# Keep:
# - docs/CREDENTIALS_AUDIT.md (current, comprehensive)
```

### Backup Files
```bash
# Already in .gitignore, but can be deleted
rm docs/.\$MongerHomeLab.drawio.bkp
```

## .gitignore Improvements

Add these patterns to ensure Terraform and Kubernetes secrets are protected:

```gitignore
# Terraform
*.tfstate
*.tfstate.*
*.tfvars.json
.terraform/
.terraform.lock.hcl
terraform.tfstate.d/
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Kubernetes
kubeconfig
*.kubeconfig
secrets/
k8s-secrets/

# 1Password
.op/
*.op.json

# Environment files
.env
.env.local
*.env

# Service account tokens
*service-account*.json
*serviceaccount*.json
```

## Security Scan Results

✅ **No hardcoded secrets found**
- All passwords use variables or vault
- No API tokens in code
- No SSH keys in files
- All secrets properly managed via 1Password → Ansible Vault

✅ **Proper .gitignore coverage**
- Vault files excluded
- Vault passwords excluded
- Terraform state excluded

## Kubernetes Secrets Strategy

### Current State (Ansible/Terraform)
- **Source of Truth**: 1Password
- **Ansible**: 1Password → Ansible Vault (AES256)
- **Terraform**: 1Password → Service Account → Terraform

### Recommended for Kubernetes

#### Option 1: External Secrets Operator (Recommended)
```yaml
# Install External Secrets Operator
# Syncs secrets from 1Password to Kubernetes automatically

apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: onepassword
spec:
  provider:
    onepassword:
      connectHost: https://connect.1password.com
      vaults:
        homelab: 1
      auth:
        secretRef:
          connectToken:
            name: onepassword-token
            key: token
```

**Pros:**
- Automatic sync from 1Password
- No secrets in git
- Audit trail in 1Password
- Rotation support

**Cons:**
- Requires 1Password Connect server
- Additional infrastructure

#### Option 2: Sealed Secrets (GitOps Friendly)
```bash
# Encrypt secrets that can be stored in git
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# Only the cluster can decrypt them
```

**Pros:**
- Secrets can be in git (encrypted)
- GitOps compatible
- No external dependencies

**Cons:**
- Manual encryption process
- Rotation requires re-encryption

#### Option 3: SOPS + Age (Simple)
```bash
# Encrypt YAML files with age
sops --encrypt --age <public-key> secret.yaml > secret.enc.yaml

# Decrypt in CI/CD or manually
sops --decrypt secret.enc.yaml | kubectl apply -f -
```

**Pros:**
- Simple, lightweight
- Works with any YAML
- Can use 1Password for age keys

**Cons:**
- Manual process
- Requires SOPS in workflow

### Recommended Approach for Your Homelab

**Phase 1: Manual (Current)**
```bash
# Use Ansible to deploy K8s secrets from vault
ansible-playbook playbook/deploy_k8s_secrets.yml
```

**Phase 2: External Secrets Operator**
```bash
# Install 1Password Connect in cluster
# Configure External Secrets Operator
# Automatic sync from 1Password
```

**Phase 3: GitOps with Sealed Secrets**
```bash
# For non-sensitive config: plain YAML
# For secrets: Sealed Secrets
# All in git, ArgoCD manages deployment
```

## Additional Security Measures

### 1. Pre-commit Hooks
```bash
# Install pre-commit framework
pip install pre-commit

# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

### 2. Vault Password Rotation
```bash
# Rotate Ansible vault password quarterly
ansible-vault rekey inventory/raclette/group_vars/vault.yml

# Update in 1Password
op item edit "ansible-vault" password="new-password"

# Update local file
echo "new-password" > ~/.vault_pass
```

### 3. Service Account Token Rotation
```bash
# Rotate 1Password service account token annually
# Update in environment:
export OP_SERVICE_ACCOUNT_TOKEN="new-token"

# Update in CI/CD secrets
```

### 4. SSH Key Rotation
```bash
# Rotate infrastructure SSH keys annually
ssh-keygen -t ed25519 -C "infrastructure-$(date +%Y)"

# Update in 1Password
op item edit "Spraycheese Infrastructure SSH Key" "public key"="ssh-ed25519 ..."

# Sync to vault
bash scripts/sync_secrets_from_1password_v2.sh

# Deploy to infrastructure
ansible-playbook playbook/update_ssh_keys.yml
```

## Monitoring & Auditing

### 1Password Audit
- Review access logs monthly
- Check for unauthorized access
- Verify service account usage

### Ansible Vault Audit
```bash
# Check vault file modification dates
find inventory -name "vault.yml" -ls

# Verify vault encryption
ansible-vault view inventory/raclette/group_vars/vault.yml --vault-password-file ~/.vault_pass
```

### Terraform State Audit
```bash
# Ensure no secrets in state (they will be there, but encrypted in remote backend)
terraform show | grep -i "password\|token\|secret"
```

## Summary

✅ **Current Security Posture: GOOD**
- No secrets in git
- 1Password as source of truth
- Ansible Vault for automation
- Terraform using 1Password provider

🎯 **Next Steps:**
1. Remove duplicate files (see above)
2. Enhance .gitignore for K8s
3. Plan External Secrets Operator for K8s
4. Implement pre-commit hooks
5. Document rotation schedule

---

**Last Updated**: 2025-10-20  
**Next Review**: 2025-11-20
