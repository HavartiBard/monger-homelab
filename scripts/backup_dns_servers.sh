#!/bin/bash
# Simple DNS backup script that doesn't require Ansible
# Run this from the automation container

set -e

TIMESTAMP=$(date +%Y-%m-%d-%H%M)
BACKUP_BASE="/mnt/unraid-backups/technitium"
DNS_SERVERS=("192.168.20.29" "192.168.20.28")
DNS_NAMES=("technitium-dns1" "technitium-dns2")

echo "========================================="
echo "DNS Backup - $TIMESTAMP"
echo "========================================="
echo ""

for i in "${!DNS_SERVERS[@]}"; do
    SERVER="${DNS_SERVERS[$i]}"
    NAME="${DNS_NAMES[$i]}"
    
    echo "[$((i+1))/2] Backing up $NAME ($SERVER)..."
    
    # Create temp backup on remote server
    ssh automation@$SERVER "sudo tar czf /tmp/dns-backup-$TIMESTAMP.tar.gz -C /etc dns 2>/dev/null || sudo tar czf /tmp/dns-backup-$TIMESTAMP.tar.gz -C /opt technitium 2>/dev/null || echo 'No DNS data found'"
    
    # Copy to local backup location
    scp automation@$SERVER:/tmp/dns-backup-$TIMESTAMP.tar.gz $BACKUP_BASE/$NAME-$TIMESTAMP.tar.gz
    
    # Cleanup remote temp file
    ssh automation@$SERVER "sudo rm -f /tmp/dns-backup-$TIMESTAMP.tar.gz"
    
    echo "✅ $NAME backed up successfully"
done

echo ""
echo "========================================="
echo "Cleanup old backups (>30 days)..."
echo "========================================="
find $BACKUP_BASE -name "*.tar.gz" -mtime +30 -delete
echo "✅ Cleanup complete"

echo ""
echo "========================================="
echo "Backup Summary"
echo "========================================="
echo "Total backups: $(ls -1 $BACKUP_BASE/*.tar.gz 2>/dev/null | wc -l)"
echo "Total size: $(du -sh $BACKUP_BASE | cut -f1)"
echo "Location: $BACKUP_BASE"
echo "========================================="
