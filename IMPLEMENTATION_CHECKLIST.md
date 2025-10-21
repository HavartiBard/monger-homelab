# Technitium Backup Refactoring - Implementation Checklist

## Pre-Implementation ✅ (Completed)

- [x] Refactor playbooks to use vault tokens
- [x] Create group_vars and host_vars structure
- [x] Update all API-based playbooks
- [x] Create comprehensive documentation
- [x] Preserve old backup method for rollback
- [x] Create helper scripts

## Implementation Steps (To Do)

### Phase 1: Vault Setup (Required)

- [ ] **Step 1.1**: Edit Ansible Vault
  ```bash
  cd /mnt/d/cluster/monger-homelab
  ansible-vault edit inventory/raclette/group_vars/vault.yml
  ```

- [ ] **Step 1.2**: Add tokens to vault
  ```yaml
  # Add these lines to vault.yml:
  vault_technitium_tokens:
    technitium-dns1: "f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8"
    technitium-dns2: "819048ea9356f23157ab915dc4e8f9e2927ccaa206a207f61982c41da8842615"
  ```

- [ ] **Step 1.3**: Save and exit vault
  - Vault will re-encrypt automatically
  - Verify file is still encrypted: `file inventory/raclette/group_vars/vault.yml`

### Phase 2: Testing (Required)

- [ ] **Step 2.1**: Test token loading
  ```bash
  ansible -i inventory/raclette/inventory.ini technitium-dns1 \
    -m debug -a "var=technitium_api_token" \
    --ask-vault-pass
  ```
  Expected: Should display the token (decrypted)

- [ ] **Step 2.2**: Test API connection manually
  ```bash
  curl -X POST "http://192.168.20.29:5380/api/settings/backup" \
    -d "token=f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8" \
    -o test-backup.zip
  
  ls -lh test-backup.zip
  ```
  Expected: Should create a .zip file (several MB)

- [ ] **Step 2.3**: Dry run backup playbook
  ```bash
  ansible-playbook -i inventory/raclette/inventory.ini \
    playbook/technitium_daily_backup.yml \
    --ask-vault-pass \
    --check
  ```
  Expected: Should show what would be done (no errors)

- [ ] **Step 2.4**: Test backup on single server
  ```bash
  ansible-playbook -i inventory/raclette/inventory.ini \
    playbook/technitium_daily_backup.yml \
    --ask-vault-pass \
    --limit technitium-dns1
  ```
  Expected: Backup created in `/mnt/unraid-backups/technitium/`

- [ ] **Step 2.5**: Verify backup file
  ```bash
  ls -lh /mnt/unraid-backups/technitium/*.zip | tail -1
  unzip -l /mnt/unraid-backups/technitium/technitium-dns1-*.zip | head -20
  ```
  Expected: Valid .zip file with config.json and other files

- [ ] **Step 2.6**: Test backup on all servers
  ```bash
  ansible-playbook -i inventory/raclette/inventory.ini \
    playbook/technitium_daily_backup.yml \
    --ask-vault-pass
  ```
  Expected: Backups for both servers created

### Phase 3: Automation Setup (Recommended)

- [ ] **Step 3.1**: Create vault password file
  ```bash
  echo "your_vault_password" > ~/.vault_pass
  chmod 600 ~/.vault_pass
  ```

- [ ] **Step 3.2**: Test with password file
  ```bash
  ansible-playbook -i inventory/raclette/inventory.ini \
    playbook/technitium_daily_backup.yml \
    --vault-password-file ~/.vault_pass \
    --limit technitium-dns1
  ```
  Expected: Works without password prompt

- [ ] **Step 3.3**: Set up cron job
  ```bash
  crontab -e
  
  # Add this line:
  0 2 * * * cd /mnt/d/cluster/monger-homelab && /usr/bin/ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml --vault-password-file ~/.vault_pass >> /tmp/technitium-backup.log 2>&1
  ```

- [ ] **Step 3.4**: Verify cron job
  ```bash
  crontab -l | grep technitium
  ```
  Expected: Should show the cron entry

- [ ] **Step 3.5**: Test cron execution (optional)
  ```bash
  # Temporarily change cron to run in 5 minutes
  # Wait 5 minutes
  # Check log
  tail -f /tmp/technitium-backup.log
  ```

### Phase 4: Validation (Recommended)

- [ ] **Step 4.1**: Test backup restore (on test server or backup instance)
  1. Go to `http://192.168.20.29:5380`
  2. Login with admin credentials
  3. Settings → Backup & Restore
  4. Upload recent backup .zip
  5. Click Restore
  6. Verify settings restored correctly

- [ ] **Step 4.2**: Verify backup retention
  ```bash
  # Create some test backups with old dates
  touch -t 202401010000 /mnt/unraid-backups/technitium/test-old.zip
  
  # Run cleanup
  ansible-playbook -i inventory/raclette/inventory.ini \
    playbook/technitium_daily_backup.yml \
    --vault-password-file ~/.vault_pass \
    --tags cleanup
  
  # Verify old file was deleted
  ls /mnt/unraid-backups/technitium/test-old.zip
  ```
  Expected: Old test file should be deleted

- [ ] **Step 4.3**: Monitor first automated backup
  ```bash
  # Check log after first automated run
  tail -100 /tmp/technitium-backup.log
  
  # Verify backups were created
  ls -lh /mnt/unraid-backups/technitium/*.zip | tail -5
  ```

### Phase 5: Documentation & Cleanup (Recommended)

- [ ] **Step 5.1**: Document vault password location
  - Where is `~/.vault_pass` stored?
  - Who has access?
  - Is it backed up securely?

- [ ] **Step 5.2**: Schedule token rotation reminder
  - Add calendar reminder for 90 days
  - Document token rotation procedure

- [ ] **Step 5.3**: Update team documentation
  - Notify team of new backup method
  - Share QUICKSTART_BACKUP.md
  - Schedule training if needed

- [ ] **Step 5.4**: Test disaster recovery procedure
  - Document steps to restore from backup
  - Test on non-production server
  - Time the recovery process

- [ ] **Step 5.5**: Set up monitoring (optional)
  - Monitor backup file creation
  - Alert on backup failures
  - Track backup size trends

### Phase 6: Cleanup Old Method (Optional)

- [ ] **Step 6.1**: Verify new method working for 1 week
  ```bash
  # Check that backups are being created daily
  ls -lt /mnt/unraid-backups/technitium/*.zip | head -10
  ```

- [ ] **Step 6.2**: Archive old .tar.gz backups
  ```bash
  mkdir -p /mnt/unraid-backups/technitium/archive-old-method
  mv /mnt/unraid-backups/technitium/*.tar.gz /mnt/unraid-backups/technitium/archive-old-method/
  ```

- [ ] **Step 6.3**: Remove old cron jobs (if any)
  ```bash
  crontab -e
  # Remove any old backup cron jobs
  ```

## Verification Commands

### Quick Health Check
```bash
# Check recent backups
ls -lh /mnt/unraid-backups/technitium/*.zip | tail -5

# Check backup count
find /mnt/unraid-backups/technitium/ -name "*.zip" -mtime -7 | wc -l
# Expected: 14 (2 servers × 7 days)

# Check total backup size
du -sh /mnt/unraid-backups/technitium/

# Check last backup time
stat /mnt/unraid-backups/technitium/*.zip | grep Modify | tail -2
```

### Test API Access
```bash
# Test token for server 1
curl -X GET "http://192.168.20.29:5380/api/zones/list?token=f6253f0f9c4bd2c0952eb5d8b807b4a44550d5c785789d906e7ef1b94a666ed8"

# Test token for server 2
curl -X GET "http://192.168.20.28:5380/api/zones/list?token=819048ea9356f23157ab915dc4e8f9e2927ccaa206a207f61982c41da8842615"
```

### Check Ansible Configuration
```bash
# List all technitium hosts
ansible -i inventory/raclette/inventory.ini technitium_dns --list-hosts

# Check variables for each host
ansible -i inventory/raclette/inventory.ini technitium-dns1 -m debug -a "var=hostvars[inventory_hostname]" --ask-vault-pass

# Test connectivity
ansible -i inventory/raclette/inventory.ini technitium_dns -m ping
```

## Rollback Procedure

If issues occur, rollback to old method:

1. **Stop new cron job**
   ```bash
   crontab -e
   # Comment out new backup line
   ```

2. **Use old backup playbook**
   ```bash
   ansible-playbook -i inventory/raclette/inventory.ini \
     playbook/technitium_daily_backup_old.yml
   ```

3. **Restore old cron job** (if you had one)

4. **Report issues** and debug before trying again

## Success Criteria

- [ ] Vault contains encrypted tokens
- [ ] Tokens load correctly in playbooks
- [ ] API authentication works
- [ ] Backups created successfully
- [ ] Backup files are valid .zip format
- [ ] Backups can be restored via UI
- [ ] Automated backups run daily
- [ ] Old backups cleaned up after 30 days
- [ ] No hardcoded tokens in playbooks
- [ ] Documentation is complete
- [ ] Team is trained on new method

## Timeline Estimate

- **Phase 1 (Vault Setup)**: 10 minutes
- **Phase 2 (Testing)**: 30 minutes
- **Phase 3 (Automation)**: 15 minutes
- **Phase 4 (Validation)**: 30 minutes
- **Phase 5 (Documentation)**: 20 minutes
- **Phase 6 (Cleanup)**: 10 minutes

**Total**: ~2 hours (can be done in stages)

## Support Resources

- **Quick Start**: `playbook/QUICKSTART_BACKUP.md`
- **Full Guide**: `playbook/README_TECHNITIUM_BACKUP_REFACTOR.md`
- **API Setup**: `playbook/README_TECHNITIUM_API_SETUP.md`
- **Architecture**: `docs/TECHNITIUM_BACKUP_ARCHITECTURE.md`
- **Summary**: `REFACTOR_SUMMARY.md`

## Notes

- Keep vault password secure
- Test restores periodically
- Rotate tokens every 90 days
- Monitor backup logs
- Keep old method available for rollback
- Document any issues encountered

## Sign-off

- [ ] Implementation completed by: ________________
- [ ] Date: ________________
- [ ] Tested by: ________________
- [ ] Date: ________________
- [ ] Approved by: ________________
- [ ] Date: ________________

---

**Current Status**: Ready for implementation
**Next Action**: Phase 1 - Add tokens to vault
**Estimated Time**: 2 hours total
