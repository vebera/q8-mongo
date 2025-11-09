#!/bin/bash

# MongoDB Backup Script
# Creates backups of all databases or specific tenant database

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

BACKUP_DIR="${MONGO_BACKUP_DIR:-/var/backups/mongodb}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="q8-mongodb"

# Function to backup all databases
backup_all() {
  echo -e "${GREEN}📦 Creating backup of all databases...${NC}"
  
  BACKUP_PATH="${BACKUP_DIR}/full_${DATE}"
  mkdir -p "${BACKUP_PATH}"
  
  docker compose exec -T "${CONTAINER_NAME}" mongodump \
    --uri="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@localhost:27017/?authSource=admin" \
    --out="/backup/full_${DATE}" || \
  docker compose exec -T "${CONTAINER_NAME}" mongodump \
    --host localhost:27017 \
    --username "${MONGO_USER}" \
    --password "${MONGO_PASSWORD}" \
    --authenticationDatabase admin \
    --out="/backup/full_${DATE}"
  
  # Compress backup
  cd "${BACKUP_DIR}"
  tar -czf "full_${DATE}.tar.gz" "full_${DATE}"
  rm -rf "full_${DATE}"
  
  echo -e "${GREEN}✅ Backup created: full_${DATE}.tar.gz${NC}"
}

# Function to backup specific tenant database
backup_tenant() {
  local TENANT_ID=$1
  
  if [ -z "$TENANT_ID" ]; then
    echo -e "${RED}❌ Tenant ID required${NC}"
    echo "Usage: $0 tenant <tenantId>"
    exit 1
  fi
  
  echo -e "${GREEN}📦 Creating backup of tenant: ${TENANT_ID}...${NC}"
  
  BACKUP_PATH="${BACKUP_DIR}/tenant_${TENANT_ID}_${DATE}"
  mkdir -p "${BACKUP_PATH}"
  
  docker compose exec -T "${CONTAINER_NAME}" mongodump \
    --uri="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@localhost:27017/?authSource=admin" \
    --db="q8_tenant_${TENANT_ID}" \
    --out="/backup/tenant_${TENANT_ID}_${DATE}" || \
  docker compose exec -T "${CONTAINER_NAME}" mongodump \
    --host localhost:27017 \
    --username "${MONGO_USER}" \
    --password "${MONGO_PASSWORD}" \
    --authenticationDatabase admin \
    --db="q8_tenant_${TENANT_ID}" \
    --out="/backup/tenant_${TENANT_ID}_${DATE}"
  
  # Compress backup
  cd "${BACKUP_DIR}"
  tar -czf "tenant_${TENANT_ID}_${DATE}.tar.gz" "tenant_${TENANT_ID}_${DATE}"
  rm -rf "tenant_${TENANT_ID}_${DATE}"
  
  echo -e "${GREEN}✅ Backup created: tenant_${TENANT_ID}_${DATE}.tar.gz${NC}"
}

# Function to cleanup old backups
cleanup_backups() {
  echo -e "${YELLOW}🧹 Cleaning up backups older than ${RETENTION_DAYS} days...${NC}"
  
  find "${BACKUP_DIR}" -name "*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete
  
  echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Function to list backups
list_backups() {
  echo -e "${GREEN}📋 Available backups:${NC}"
  ls -lh "${BACKUP_DIR}"/*.tar.gz 2>/dev/null || echo "No backups found"
}

# Main
case "$1" in
  all)
    backup_all
    cleanup_backups
    ;;
  tenant)
    backup_tenant "$2"
    cleanup_backups
    ;;
  cleanup)
    cleanup_backups
    ;;
  list)
    list_backups
    ;;
  *)
    echo "MongoDB Backup Script"
    echo ""
    echo "Usage: $0 {all|tenant|cleanup|list}"
    echo ""
    echo "Commands:"
    echo "  all              Backup all databases"
    echo "  tenant <id>     Backup specific tenant database"
    echo "  cleanup          Remove backups older than retention period"
    echo "  list             List all available backups"
    echo ""
    exit 1
    ;;
esac

