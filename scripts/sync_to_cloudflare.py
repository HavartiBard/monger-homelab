#!/usr/bin/env python3
"""
Sync DNS records to Cloudflare

Reads config/dns_records_cloudflare.json and pushes records to Cloudflare DNS.

Prerequisites:
    pip install cloudflare

Environment Variables:
    CLOUDFLARE_API_TOKEN - Cloudflare API token with DNS edit permissions
    CLOUDFLARE_ZONE_ID - Zone ID for klsll.com

Usage:
    export CLOUDFLARE_API_TOKEN="your-token"
    export CLOUDFLARE_ZONE_ID="your-zone-id"
    python3 scripts/sync_to_cloudflare.py
"""

import os
import json
import sys
from pathlib import Path

try:
    import CloudFlare
except ImportError:
    print("Error: cloudflare library not installed")
    print("Install with: pip install cloudflare")
    sys.exit(1)

# Paths
SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent
CONFIG_DIR = REPO_ROOT / 'config'
CLOUDFLARE_RECORDS = CONFIG_DIR / 'dns_records_cloudflare.json'


def load_cloudflare_records():
    """Load records to sync"""
    if not CLOUDFLARE_RECORDS.exists():
        print(f"Error: {CLOUDFLARE_RECORDS} not found")
        print("Run: python3 scripts/generate_dns_zones.py first")
        sys.exit(1)
    
    with open(CLOUDFLARE_RECORDS, 'r') as f:
        return json.load(f)


def sync_to_cloudflare():
    """Sync records to Cloudflare"""
    
    # Get credentials from environment
    api_token = os.getenv('CLOUDFLARE_API_TOKEN')
    zone_id = os.getenv('CLOUDFLARE_ZONE_ID')
    
    if not api_token or not zone_id:
        print("Error: Missing environment variables")
        print("Required:")
        print("  CLOUDFLARE_API_TOKEN")
        print("  CLOUDFLARE_ZONE_ID")
        sys.exit(1)
    
    # Load records
    records = load_cloudflare_records()
    print(f"📡 Syncing {len(records)} records to Cloudflare...")
    
    # Initialize Cloudflare client
    cf = CloudFlare.CloudFlare(token=api_token)
    
    # Get existing records
    try:
        existing_records = cf.zones.dns_records.get(zone_id)
        existing_map = {(r['name'], r['type']): r for r in existing_records}
    except CloudFlare.exceptions.CloudFlareAPIError as e:
        print(f"Error fetching existing records: {e}")
        sys.exit(1)
    
    # Sync each record
    for record in records:
        record_name = f"{record['name']}.klsll.com"
        record_type = record['type']
        key = (record_name, record_type)
        
        try:
            if key in existing_map:
                # Update existing record
                existing_id = existing_map[key]['id']
                cf.zones.dns_records.put(zone_id, existing_id, data=record)
                print(f"  ✅ Updated: {record_name} ({record_type})")
            else:
                # Create new record
                record['name'] = record_name
                cf.zones.dns_records.post(zone_id, data=record)
                print(f"  ✅ Created: {record_name} ({record_type})")
        
        except CloudFlare.exceptions.CloudFlareAPIError as e:
            print(f"  ❌ Error for {record_name}: {e}")
    
    print("\n✅ Cloudflare sync complete!")


if __name__ == '__main__':
    sync_to_cloudflare()
