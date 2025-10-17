# Homelab Software Versions

This document tracks the standard software versions used across the homelab infrastructure.

## Version Management

Versions are defined in two places:
- **Terraform**: `terraform/vars.tf` - `software_versions` variable
- **Ansible**: `group_vars/all.yml` - `software_versions` section

**Keep these in sync!**

## Current Versions

| Software | Version | Notes |
|----------|---------|-------|
| **Ansible Core** | 2.17 | Required for automation container |
| **Python** | 3.10+ | Minimum version for Ansible 2.17+ |
| **Technitium DNS** | latest | DNS server version |
| **Ubuntu LTS** | 22.04 | Standard OS for VMs/LXC |

## Python Dependencies

### Required Packages (Ansible 2.17+)
- `python3`
- `python3-pip`
- `python3-apt`
- `python3-setuptools`
- `python3-packaging`

### Removed Packages (Conflicts)
- `python3-six` - Conflicts with Ansible 2.17+

## Compatibility Matrix

| Component | Ansible | Python | Ubuntu |
|-----------|---------|--------|--------|
| **Automation Container** | 2.17 | 3.10+ | 22.04 |
| **DNS Servers** | N/A | 3.10+ | 22.04 |
| **Proxmox Nodes** | N/A | 3.11+ | Proxmox VE 8.x |

## Upgrade Path

### When Upgrading Ansible

1. Update `terraform/vars.tf` - `software_versions.ansible_core`
2. Update `group_vars/all.yml` - `software_versions.ansible_core`
3. Check Python compatibility requirements
4. Update `python_packages` list if needed
5. Test on a single DNS server first
6. Run `technitium_dns.yml` playbook to upgrade all servers

### When Upgrading Python

1. Update `terraform/vars.tf` - `software_versions.python_min`
2. Update `group_vars/all.yml` - `software_versions.python_min`
3. Update `python_packages` list if new packages required
4. Test compatibility with current Ansible version
5. Deploy via `technitium_dns.yml` playbook

### When Upgrading Ubuntu

1. Update `terraform/vars.tf` - `software_versions.ubuntu_lts`
2. Update `group_vars/all.yml` - `software_versions.ubuntu_lts`
3. Update LXC template in `automation-lxc.tf`
4. Test new template before deploying
5. Plan migration strategy for existing servers

## Version History

| Date | Change | Reason |
|------|--------|--------|
| 2025-10-17 | Ansible 2.17, Python 3.10+, Ubuntu 22.04 | Initial version tracking |
| 2025-10-17 | Removed python3-six | Conflicts with Ansible 2.17+ |

## Checking Versions

### Automation Container
```bash
ssh james@192.168.20.50
sudo su - automation
ansible --version
python3 --version
```

### DNS Servers
```bash
ssh automation@192.168.20.29
python3 --version
dpkg -l | grep python3
```

### Verify Compatibility
```bash
# From automation container
cd /opt/automation/monger-homelab
ansible -i inventory/raclette/inventory.ini technitium_dns -m ping
```

## Troubleshooting

### "No module named 'ansible.module_utils.six.moves'"
- **Cause**: python3-six conflicts with Ansible 2.17+
- **Fix**: Run `technitium_dns.yml` playbook to remove python3-six

### "Ansible version too old"
- **Cause**: Automation container has outdated Ansible
- **Fix**: `sudo pip3 install --upgrade ansible-core`

### "Python version incompatible"
- **Cause**: Target server has Python < 3.10
- **Fix**: Upgrade Ubuntu or install newer Python

---

**Last Updated**: 2025-10-17  
**Maintained By**: Infrastructure Team
