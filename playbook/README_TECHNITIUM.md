# Technitium DNS Deployment

## What This Playbook Does

### Phase 1: System Bootstrap
- ✅ Updates and upgrades all packages
- ✅ Installs base tools (curl, zsh, vim, htop, net-tools)
- ✅ Installs and configures Oh My Zsh
- ✅ Copies custom .zshrc (if exists)
- ✅ Disables firewalld (if installed)
- ✅ Enables IPv4 forwarding
- ✅ Disables swap

### Phase 2: Docker Installation
- ✅ Installs Docker CE and dependencies
- ✅ Configures Docker to start on boot

### Phase 3: Technitium DNS Deployment
- ✅ Creates data directory at `/opt/technitium`
- ✅ Deploys Technitium DNS v13.0.2 in Docker
- ✅ Exposes ports:
  - 53/tcp & 53/udp (DNS)
  - 5380/tcp (Web Interface)
  - 67/udp (DHCP - optional)
- ✅ Configures auto-restart

## Usage

### Deploy to both DNS servers:
```bash
cd d:\cluster\monger-homelab
ansible-playbook -i inventory/raclette/hosts.ini playbook/technitium_dns.yml
```

### Deploy to single server:
```bash
ansible-playbook -i inventory/raclette/hosts.ini playbook/technitium_dns.yml --limit technitium-dns1
```

### Check connectivity first:
```bash
ansible -i inventory/raclette/hosts.ini technitium_dns -m ping
```

## Post-Installation

### Access Web Interfaces:
- **DNS1**: http://192.168.20.29:5380
- **DNS2**: http://192.168.20.28:5380

### Default Credentials:
- Username: `admin`
- Password: `admin`

**⚠️ CHANGE THE PASSWORD IMMEDIATELY!**

## Version Management

To upgrade Technitium:
1. Edit `technitium_version` in `technitium_dns.yml`
2. Re-run the playbook

Current version: **latest** (auto-updates to newest stable)

## Troubleshooting

### Check if Technitium is running:
```bash
ssh james@192.168.20.29 "docker ps | grep technitium"
ssh james@192.168.20.28 "docker ps | grep technitium"
```

### View Technitium logs:
```bash
ssh james@192.168.20.29 "docker logs technitium"
ssh james@192.168.20.28 "docker logs technitium"
```

### Restart Technitium:
```bash
ssh james@192.168.20.29 "docker restart technitium"
ssh james@192.168.20.28 "docker restart technitium"
```

### Check DNS resolution:
```bash
dig @192.168.20.29 google.com
dig @192.168.20.28 google.com
```
