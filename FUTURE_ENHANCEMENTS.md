# Future Enhancements

## Infrastructure Upgrades

### Proxmox Updates
- [ ] **Update Proxmox to latest version**
  - Current: Proxmox VE (version TBD)
  - Target: Latest stable release
  - Benefits:
    - Ubuntu 24.04 LXC support
    - Latest security patches
    - New features and performance improvements
  - Plan:
    1. Backup all VMs/LXCs
    2. Update one node at a time
    3. Test after each node
    4. Migrate automation container to Ubuntu 24.04 after update

### Automation Enhancements
- [ ] **Deploy n8n for visual workflows**
  - Replace cron jobs with n8n workflows
  - Add Slack/Discord notifications
  - Build monitoring dashboard
  - Git-driven deployments via webhooks

### DNS/DHCP
- [ ] **Cloudflare integration**
  - Sync public DNS records to Cloudflare
  - Setup Cloudflare Tunnel for secure access
  - Implement split-horizon DNS

### Monitoring & Observability
- [ ] **Prometheus + Grafana**
  - Monitor DNS query metrics
  - DHCP lease tracking
  - Backup success/failure alerts
  - Infrastructure health dashboard

### Security
- [ ] **Certificate automation**
  - Let's Encrypt for internal services
  - Automated renewal via n8n
  - Certificate monitoring

### Backup Enhancements
- [ ] **Offsite backups**
  - Sync to cloud storage (Backblaze B2, AWS S3)
  - Encrypted backups
  - Automated restore testing

## Priority

| Priority | Item | Effort | Impact |
|----------|------|--------|--------|
| **High** | n8n deployment | Medium | High |
| **High** | Monitoring setup | Medium | High |
| **Medium** | Proxmox updates | Low | Medium |
| **Medium** | Cloudflare sync | Low | Medium |
| **Low** | Offsite backups | Medium | Low |
| **Low** | Certificate automation | Low | Low |

## Timeline

### Q1 2025
- ✅ Automation LXC deployed
- ✅ Daily backups running
- ✅ DNS zone management automated

### Q2 2025
- [ ] Deploy n8n
- [ ] Setup monitoring
- [ ] Cloudflare integration

### Q3 2025
- [ ] Update Proxmox cluster
- [ ] Migrate to Ubuntu 24.04 LXC
- [ ] Offsite backup solution

### Q4 2025
- [ ] Certificate automation
- [ ] Advanced monitoring
- [ ] Documentation updates

---

**Current Status:** ✅ Core automation infrastructure complete!

**Next Steps:** Get backups running reliably, then enhance with n8n when ready.
