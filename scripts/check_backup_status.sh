#!/bin/bash
# Check status of Technitium DNS backups

BACKUP_DIR="/mnt/unraid-backups/technitium"
LOG_FILE="/tmp/dns-backup.log"

echo "========================================="
echo "Technitium DNS Backup Status"
echo "========================================="
echo ""

# Check if backup directory is accessible
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup directory not found: $BACKUP_DIR"
    echo "Run: scripts/enable_daily_backups.sh"
    exit 1
fi

# Check mount
if ! mount | grep -q "/mnt/unraid-backups"; then
    echo "⚠️  Warning: Unraid not mounted"
    echo "Run: sudo mount -a"
    echo ""
fi

# List recent backups
echo "Recent Backups (Last 10):"
echo "-------------------------"
ls -lht "$BACKUP_DIR" | head -11 | tail -10

echo ""
echo "Backup Statistics:"
echo "------------------"

# Count backups
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "*.tar.gz" | wc -l)
echo "Total Backups: $TOTAL_BACKUPS"

# Total size
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
echo "Total Size: $TOTAL_SIZE"

# Oldest backup
OLDEST=$(find "$BACKUP_DIR" -name "*.tar.gz" -printf '%T+ %p\n' 2>/dev/null | sort | head -1 | cut -d' ' -f1)
if [ -n "$OLDEST" ]; then
    echo "Oldest Backup: $OLDEST"
fi

# Newest backup
NEWEST=$(find "$BACKUP_DIR" -name "*.tar.gz" -printf '%T+ %p\n' 2>/dev/null | sort -r | head -1 | cut -d' ' -f1)
if [ -n "$NEWEST" ]; then
    echo "Newest Backup: $NEWEST"
fi

echo ""
echo "Cron Job Status:"
echo "----------------"
if crontab -l 2>/dev/null | grep -q "technitium_daily_backup"; then
    echo "✅ Cron job is configured"
    echo ""
    echo "Schedule:"
    crontab -l | grep "technitium_daily_backup"
else
    echo "❌ Cron job not found"
    echo "Run: scripts/enable_daily_backups.sh"
fi

echo ""
echo "Recent Log Entries:"
echo "-------------------"
if [ -f "$LOG_FILE" ]; then
    tail -20 "$LOG_FILE"
else
    echo "No log file found at $LOG_FILE"
fi

echo ""
echo "========================================="
echo ""
echo "Commands:"
echo "  - View all backups: ls -lh $BACKUP_DIR"
echo "  - Watch logs: tail -f $LOG_FILE"
echo "  - Manual backup: ansible-playbook -i inventory/raclette/inventory.ini playbook/technitium_daily_backup.yml"
echo ""
