#!/bin/bash

# MongoDB Restore Script
# Restores databases from backup files

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment variables
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

BACKUP_DIR="${MONGO_BACKUP_DIR:-/mnt/volume-db-prod/mongodb-backups}"
CONTAINER_NAME="q8-mongodb"

# Function to restore from backup
restore_backup() {
  local BACKUP_FILE=$1
  
  if [ -z "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Backup file required${NC}"
    echo "Usage: $0 <backup-file.tar.gz>"
    exit 1
  fi
  
  if [ ! -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    echo -e "${RED}❌ Backup file not found: ${BACKUP_DIR}/${BACKUP_FILE}${NC}"
    exit 1
  fi
  
  echo -e "${YELLOW}⚠️  WARNING: This will restore data from backup${NC}"
  echo -e "${YELLOW}⚠️  Existing data may be overwritten${NC}"
  read -p "Are you sure you want to continue? (yes/no): " CONFIRM
  
  if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
  fi
  
  echo -e "${GREEN}📦 Extracting backup...${NC}"
  cd "${BACKUP_DIR}"
  tar -xzf "${BACKUP_FILE}"
  
  # Get backup directory name (remove .tar.gz)
  BACKUP_NAME="${BACKUP_FILE%.tar.gz}"
  
  echo -e "${GREEN}🔄 Restoring from backup...${NC}"
  
  # Check if it's a full backup or tenant backup
  if [[ "$BACKUP_NAME" == full_* ]]; then
    # Full backup
    docker compose exec -T "${CONTAINER_NAME}" mongorestore \
      --uri="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@localhost:27017/?authSource=admin" \
      --drop \
      "/backup/${BACKUP_NAME}"
  elif [[ "$BACKUP_NAME" == tenant_* ]]; then
    # Extract tenant ID
    TENANT_ID=$(echo "$BACKUP_NAME" | sed 's/tenant_\([^_]*\)_.*/\1/')
    # Tenant backup
    docker compose exec -T "${CONTAINER_NAME}" mongorestore \
      --uri="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@localhost:27017/?authSource=admin" \
      --db="q8_tenant_${TENANT_ID}" \
      --drop \
      "/backup/${BACKUP_NAME}/q8_tenant_${TENANT_ID}"
  else
    echo -e "${RED}❌ Unknown backup format${NC}"
    exit 1
  fi
  
  # Cleanup extracted files
  rm -rf "${BACKUP_NAME}"
  
  echo -e "${GREEN}✅ Restore complete${NC}"
}

# Function to list available backups
list_backups() {
  echo -e "${GREEN}📋 Available backups:${NC}"
  ls -lh "${BACKUP_DIR}"/*.tar.gz 2>/dev/null || echo "No backups found"
}

# Main
if [ "$1" == "list" ]; then
  list_backups
elif [ -z "$1" ]; then
  echo "MongoDB Restore Script"
  echo ""
  echo "Usage: $0 <backup-file.tar.gz>"
  echo "   or: $0 list"
  echo ""
  echo "Examples:"
  echo "  $0 full_20240101_020000.tar.gz    # Restore full backup"
  echo "  $0 tenant_abc123_20240101.tar.gz # Restore tenant backup"
  echo "  $0 list                           # List available backups"
  exit 1
else
  restore_backup "$1"
fi

