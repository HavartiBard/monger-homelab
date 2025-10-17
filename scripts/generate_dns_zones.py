#!/usr/bin/env python3
"""
Generate dns_zones.yml from simplified record files

Merges:
- config/dns_records_manual.conf (human-edited)
- config/dns_records_terraform.conf (auto-generated)

Into:
- config/dns_zones.yml (consumed by Ansible)

Features:
- Auto-generates PTR records from A records
- Validates IP addresses and formats

Usage:
    python3 scripts/generate_dns_zones.py
"""

import yaml
from pathlib import Path
from collections import defaultdict

# Paths
SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent
CONFIG_DIR = REPO_ROOT / 'config'

MANUAL_RECORDS = CONFIG_DIR / 'dns_records_manual.conf'
TERRAFORM_RECORDS = CONFIG_DIR / 'dns_records_terraform.conf'
OUTPUT_FILE = CONFIG_DIR / 'dns_zones.yml'

# DNS Forwarders (static config)
DNS_FORWARDERS = [
    {"address": "1.1.1.1", "protocol": "Udp"},
    {"address": "1.0.0.1", "protocol": "Udp"},
]

DNS_SETTINGS = {
    "enable_doh": False,
    "enable_dnssec": True,
    "cache_minimum_ttl": 60,
    "cache_maximum_ttl": 86400,
    "enable_query_logging": False,
    "log_queries_to_file": False,
}


def parse_record_file(filepath):
    """Parse a DNS record file with zone sections"""
    records = []
    
    if not filepath.exists():
        print(f"Warning: {filepath} not found, skipping")
        return records
    
    current_zone = None
    
    with open(filepath, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            
            # Skip comments and empty lines
            if not line or line.startswith('#'):
                continue
            
            # Check for ZONE declaration
            if line.startswith('ZONE:'):
                current_zone = line.split(':', 1)[1].strip()
                continue
            
            # Check for ENDZONE
            if line == 'ENDZONE':
                current_zone = None
                continue
            
            # Must be inside a zone to parse records
            if current_zone is None:
                continue
            
            # Parse CSV: name,type,value,ttl[,cloudflare] (zone is inherited)
            parts = [p.strip() for p in line.split(',')]
            
            if len(parts) < 4 or len(parts) > 5:
                print(f"Warning: Invalid line {line_num} in {filepath.name}: {line}")
                print(f"         Expected format: name,type,value,ttl[,[CLOUDFLARE]]")
                continue
            
            name = parts[0]
            record_type = parts[1]
            value = parts[2]
            ttl = parts[3]
            cloudflare = len(parts) == 5 and parts[4].upper() == '[CLOUDFLARE]'
            
            try:
                ttl = int(ttl)
            except ValueError:
                print(f"Warning: Invalid TTL on line {line_num}: {ttl}")
                ttl = 3600
            
            records.append({
                'name': name,
                'type': record_type,
                'value': value,
                'zone': current_zone,
                'ttl': ttl,
                'cloudflare': cloudflare
            })
    
    return records


def generate_ptr_records(records):
    """Auto-generate PTR records from A records"""
    ptr_records = []
    
    for record in records:
        # Only process A records
        if record['type'] != 'A':
            continue
        
        ip = record['value']
        hostname = record['name']
        zone = record['zone']
        ttl = record['ttl']
        
        # Parse IP address (only IPv4 for now)
        try:
            octets = ip.split('.')
            if len(octets) != 4:
                continue
            
            # Determine reverse zone based on IP
            # 192.168.20.x -> 20.168.192.in-addr.arpa
            # 192.168.30.x -> 30.168.192.in-addr.arpa
            reverse_zone = f"{octets[2]}.{octets[1]}.{octets[0]}.in-addr.arpa"
            
            # PTR record name is the last octet
            ptr_name = octets[3]
            
            # PTR value is the FQDN (must end with .)
            ptr_value = f"{hostname}.{zone}."
            
            ptr_records.append({
                'name': ptr_name,
                'type': 'PTR',
                'value': ptr_value,
                'zone': reverse_zone,
                'ttl': ttl
            })
            
        except (ValueError, IndexError):
            print(f"Warning: Could not parse IP {ip} for PTR generation")
            continue
    
    return ptr_records


def group_by_zone(records):
    """Group records by zone name"""
    zones = defaultdict(list)
    
    for record in records:
        zone_name = record['zone']
        zones[zone_name].append({
            'name': record['name'],
            'type': record['type'],
            'value': record['value'],
            'ttl': record['ttl']
        })
    
    return zones


def generate_dns_zones_yaml():
    """Generate the complete dns_zones.yml file"""
    
    print("🔍 Parsing DNS record files...")
    
    # Parse both record files
    manual_records = parse_record_file(MANUAL_RECORDS)
    terraform_records = parse_record_file(TERRAFORM_RECORDS)
    
    print(f"  ✅ Manual records: {len(manual_records)}")
    print(f"  ✅ Terraform records: {len(terraform_records)}")
    
    # Generate PTR records from A records
    print("\n🔄 Auto-generating PTR records...")
    ptr_records = generate_ptr_records(manual_records + terraform_records)
    print(f"  ✅ Generated {len(ptr_records)} PTR records")
    
    # Combine all records
    all_records = manual_records + terraform_records + ptr_records
    
    # Export Cloudflare records
    export_cloudflare_records(manual_records + terraform_records)
    
    # Group by zone
    zones_dict = group_by_zone(all_records)
    
    print(f"\n📋 Zones found: {', '.join(zones_dict.keys())}")
    
    # Build the dns_zones structure
    dns_zones = []
    
    for zone_name in sorted(zones_dict.keys()):
        zone_records = zones_dict[zone_name]
        
        # Determine zone type
        zone_type = "Primary"
        
        dns_zones.append({
            'name': zone_name,
            'type': zone_type,
            'records': zone_records
        })
        
        print(f"  ✅ {zone_name}: {len(zone_records)} records")
    
    # Build final structure
    output = {
        'dns_zones': dns_zones,
        'dns_forwarders': DNS_FORWARDERS,
        'dns_settings': DNS_SETTINGS
    }
    
    # Write YAML
    print(f"\n💾 Writing to {OUTPUT_FILE.relative_to(REPO_ROOT)}...")
    
    with open(OUTPUT_FILE, 'w') as f:
        f.write("---\n")
        f.write("# DNS Zone Configuration for Technitium DNS Servers\n")
        f.write("# AUTO-GENERATED - DO NOT EDIT MANUALLY\n")
        f.write("#\n")
        f.write("# This file is generated from:\n")
        f.write("#   - config/dns_records_manual.conf (human-edited)\n")
        f.write("#   - config/dns_records_terraform.conf (auto-generated)\n")
        f.write("#   - PTR records auto-generated from A records\n")
        f.write("#\n")
        f.write("# To make changes:\n")
        f.write("#   1. Edit config/dns_records_manual.conf\n")
        f.write("#   2. Run: python3 scripts/generate_dns_zones.py\n")
        f.write("#   3. Deploy: ansible-playbook playbook/configure_dns_zones.yml\n")
        f.write("\n")
        yaml.dump(output, f, default_flow_style=False, sort_keys=False)
    
    print("✅ Done!\n")
    print("Next steps:")
    print("  1. Review: cat config/dns_zones.yml")
    print("  2. Deploy: ansible-playbook -i inventory/raclette/inventory.ini playbook/configure_dns_zones.yml")


def export_cloudflare_records(records):
    """Export records marked for Cloudflare to a separate file"""
    cloudflare_records = [r for r in records if r.get('cloudflare', False)]
    
    if not cloudflare_records:
        print("\n📡 No Cloudflare records found")
        return
    
    cloudflare_file = CONFIG_DIR / 'dns_records_cloudflare.json'
    
    # Format for Cloudflare API
    cf_records = []
    for record in cloudflare_records:
        cf_records.append({
            'type': record['type'],
            'name': record['name'],
            'content': record['value'],
            'ttl': record['ttl'],
            'proxied': False  # Set to True to use Cloudflare proxy
        })
    
    import json
    with open(cloudflare_file, 'w') as f:
        json.dump(cf_records, f, indent=2)
    
    print(f"\n📡 Cloudflare records exported: {cloudflare_file.relative_to(REPO_ROOT)}")
    print(f"   Records: {len(cf_records)}")
    print("   Use scripts/sync_to_cloudflare.py to push these records")


if __name__ == '__main__':
    generate_dns_zones_yaml()
