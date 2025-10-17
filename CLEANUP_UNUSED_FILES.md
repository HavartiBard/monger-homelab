# Cleanup Unused Files

## Files to Remove

These files were created during experimentation and are no longer needed:

### Playbooks (Experimental DHCP Config Attempts)
```bash
# Failed attempts to configure DHCP via config file injection
rm playbook/deploy_dhcp_config.yml
rm playbook/inject_dhcp_config.yml
rm playbook/inject_dhcp_fixed.yml
rm playbook/inject_dhcp_simple.yml
rm playbook/sync_dhcp_config.yml
```

**Reason:** Superseded by `configure_dhcp_api.yml` which uses the Technitium REST API properly.

### Templates (Unused Jinja2 Templates)
```bash
# Templates that were never successfully used
rm templates/dhcp_scopes.json.j2
rm templates/technitium_dhcp.config.j2
```

**Reason:** API approach doesn't need templates. Config is generated directly from YAML.

### Scripts (Superseded by API)
```bash
# Python script for config generation
rm scripts/generate_dhcp_config.py
```

**Reason:** API calls handle this directly, no intermediate script needed.

---

## Current Active Files

### ✅ Playbooks (Keep)
- `configure_dhcp_api.yml` - **DHCP configuration via API** ⭐
- `configure_dns_zones.yml` - **DNS zones via API** ⭐
- `add_dhcp_reservations.yml` - Helper for DHCP API
- `add_dns_records.yml` - Helper for DNS API
- `technitium_dns.yml` - Initial Technitium installation
- `configure_vlan30.yml` - Network configuration
- `technitium_backup_restore.yml` - Backup/restore functionality
- `technitium_daily_backup.yml` - Automated backups
- `bootstrap.yml` - VM bootstrap
- `debian_bootstrap.yml` - Debian-specific bootstrap
- `ubuntu_bootsrap.yml` - Ubuntu-specific bootstrap (typo in filename)
- `proxmox_subscription.yml` - Proxmox subscription management

### ✅ Config Files (Keep)
- `config/dhcp_scopes.yml` - DHCP configuration source of truth
- `config/dns_zones.yml` - DNS configuration source of truth

### ✅ Documentation (Keep)
- `DNS_MANAGEMENT_STRATEGY.md` - DNS management approach
- `IP_CUTOVER_GUIDE.md` - IP migration strategy
- All README files

### ✅ Scripts (Keep)
- `scripts/setup-unraid-mount.sh` - Still used for backups

---

## Cleanup Commands

Run these from the repository root:

```bash
cd /mnt/d/cluster/monger-homelab

# Remove experimental DHCP playbooks
rm playbook/deploy_dhcp_config.yml
rm playbook/inject_dhcp_config.yml
rm playbook/inject_dhcp_fixed.yml
rm playbook/inject_dhcp_simple.yml
rm playbook/sync_dhcp_config.yml

# Remove unused templates
rm templates/dhcp_scopes.json.j2
rm templates/technitium_dhcp.config.j2

# Remove superseded script
rm scripts/generate_dhcp_config.py

# Verify cleanup
echo "Remaining playbooks:"
ls playbook/*.yml

echo "Remaining templates:"
ls templates/

echo "Remaining scripts:"
ls scripts/
```

---

## Git Cleanup

After removing files, commit the cleanup:

```bash
git add -A
git commit -m "Clean up experimental DHCP config files

- Remove failed config injection playbooks
- Remove unused Jinja2 templates
- Remove superseded Python script
- Keep only API-based approach (configure_dhcp_api.yml)"

git push
```

---

## Summary

**Before:** 5 experimental DHCP playbooks + 2 templates + 1 script = 8 unused files  
**After:** 2 clean API-based playbooks (DHCP + DNS) = Simple, maintainable IaC

The API approach is:
- ✅ More reliable (no templating issues)
- ✅ Idempotent (safe to re-run)
- ✅ Easier to understand
- ✅ Properly handles dynamic vs static records
