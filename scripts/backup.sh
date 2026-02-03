#!/bin/bash

# BarangayLink Backup Script
set -e

echo "💾 Starting BarangayLink Backup..."

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="barangaylink_backup_${TIMESTAMP}"

mkdir -p "${BACKUP_DIR}"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found"
    exit 1
fi

# Backup database
echo "🗄️  Backing up database..."
docker-compose exec -T postgres pg_dump -U "${DB_USER:-barangayadmin}" "${DB_NAME:-barangaylink}" > "${BACKUP_DIR}/${BACKUP_NAME}.sql"

# Backup uploads directory
echo "📁 Backing up uploads..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}_uploads.tar.gz" ./uploads 2>/dev/null || true

# Backup logs
echo "📝 Backing up logs..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}_logs.tar.gz" ./logs 2>/dev/null || true

# Create backup info file
cat > "${BACKUP_DIR}/${BACKUP_NAME}_info.txt" << EOF
BarangayLink Backup
Timestamp: ${TIMESTAMP}
Components:
- Database: ${DB_NAME:-barangaylink}
- Uploads: $(du -sh ./uploads 2>/dev/null | cut -f1) || "0"
- Logs: $(du -sh ./logs 2>/dev/null | cut -f1) || "0"
EOF

# Create archive
echo "📦 Creating backup archive..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    "${BACKUP_DIR}/${BACKUP_NAME}.sql" \
    "${BACKUP_DIR}/${BACKUP_NAME}_uploads.tar.gz" \
    "${BACKUP_DIR}/${BACKUP_NAME}_logs.tar.gz" \
    "${BACKUP_DIR}/${BACKUP_NAME}_info.txt" \
    .env.example

# Clean up temporary files
rm -f "${BACKUP_DIR}/${BACKUP_NAME}.sql" \
      "${BACKUP_DIR}/${BACKUP_NAME}_uploads.tar.gz" \
      "${BACKUP_DIR}/${BACKUP_NAME}_logs.tar.gz" \
      "${BACKUP_DIR}/${BACKUP_NAME}_info.txt"

# Keep only last 7 backups
echo "🧹 Cleaning up old backups..."
ls -t "${BACKUP_DIR}"/*.tar.gz | tail -n +8 | xargs -r rm

BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
echo "✅ Backup completed: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"
