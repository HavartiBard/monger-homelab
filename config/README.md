# Configuration Files

This directory contains the source of truth for DNS and DHCP configuration.

## Files

### `dhcp_scopes.yml`
Defines DHCP scopes for both VLANs:
- Scope ranges (start/end IPs)
- Gateway addresses
- DNS servers
- Static reservations (MAC → IP mappings)
- Failover configuration

**Deploy changes:**
```bash
ansible-playbook -i ../inventory/raclette/inventory.ini ../playbook/configure_dhcp_api.yml
```

### `dns_zones.yml`
Defines DNS zones and records:
- Forward zones (lab.klsll.com, iot.klsll.com)
- Reverse zones (PTR records)
- A, CNAME, and PTR records
- DNS forwarders

**Deploy changes:**
```bash
ansible-playbook -i ../inventory/raclette/inventory.ini ../playbook/configure_dns_zones.yml
```

## Editing Guidelines

### Adding a New Server

1. **Add DHCP reservation** in `dhcp_scopes.yml`:
   ```yaml
   - hostname: "new-server"
     mac_address: "XX:XX:XX:XX:XX:XX"
     ip_address: "192.168.20.110"
   ```

2. **Add DNS record** in `dns_zones.yml`:
   ```yaml
   - name: "new-server"
     type: "A"
     ttl: 3600
     value: "192.168.20.110"
   ```

3. **Add PTR record** in `dns_zones.yml`:
   ```yaml
   - name: "110"
     type: "PTR"
     ttl: 3600
     value: "new-server.lab.klsll.com."
   ```

4. **Deploy both configs**

### Validation

Before committing changes:
- ✅ Check YAML syntax
- ✅ Verify IP addresses don't conflict
- ✅ Ensure MAC addresses are unique
- ✅ Confirm DNS names follow naming conventions

## See Also

- [DNS Management Strategy](../DNS_MANAGEMENT_STRATEGY.md) - How static vs dynamic DNS works
- [DHCP API Playbook](../playbook/configure_dhcp_api.yml) - DHCP deployment
- [DNS Zones Playbook](../playbook/configure_dns_zones.yml) - DNS deployment
