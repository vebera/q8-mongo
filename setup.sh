#!/bin/bash

# Q8 MongoDB Production Setup Script
# This script sets up the production MongoDB environment

set -e

echo "🚀 Q8 MongoDB Production Setup"
echo "=============================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}❌ Please run as root or with sudo${NC}"
  exit 1
fi

# Check if .env exists
if [ ! -f .env ]; then
  echo -e "${YELLOW}⚠️  .env file not found. Creating from .env.example...${NC}"
  cp .env.example .env
  echo -e "${GREEN}✅ Created .env file. Please edit it with your configuration.${NC}"
  echo ""
  read -p "Press Enter after editing .env file to continue..."
fi

# Source environment variables
set -a
source .env
set +a

# Create directories
echo "📁 Creating directories..."
mkdir -p "${MONGO_DATA_DIR:-/var/lib/mongodb}"
mkdir -p "${MONGO_CONFIG_DIR:-/var/lib/mongodb-config}"
mkdir -p "${MONGO_LOG_DIR:-/var/log/mongodb}"
mkdir -p "${MONGO_BACKUP_DIR:-/var/backups/mongodb}"
mkdir -p config

# Set permissions
echo "🔐 Setting permissions..."
chown -R 999:999 "${MONGO_DATA_DIR:-/var/lib/mongodb}"
chown -R 999:999 "${MONGO_CONFIG_DIR:-/var/lib/mongodb-config}"
chown -R 999:999 "${MONGO_LOG_DIR:-/var/log/mongodb}"
chmod 755 "${MONGO_BACKUP_DIR:-/var/backups/mongodb}"

# Generate MongoDB keyfile if it doesn't exist
if [ ! -f config/mongodb-keyfile ]; then
  echo "🔑 Generating MongoDB keyfile..."
  openssl rand -base64 756 > config/mongodb-keyfile
  chmod 400 config/mongodb-keyfile
  chown 999:999 config/mongodb-keyfile
  echo -e "${GREEN}✅ Generated MongoDB keyfile${NC}"
fi

# Check if password is still default
if grep -q "CHANGE_THIS" .env; then
  echo -e "${RED}❌ Please update MONGO_PASSWORD in .env file${NC}"
  echo -e "${YELLOW}💡 Generate a strong password: openssl rand -base64 32${NC}"
  exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
  echo -e "${RED}❌ Docker is not installed${NC}"
  exit 1
fi

if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
  echo -e "${RED}❌ Docker Compose is not installed${NC}"
  exit 1
fi

# Start MongoDB
echo "🐳 Starting MongoDB container..."
docker compose up -d

# Wait for MongoDB to be ready
echo "⏳ Waiting for MongoDB to be ready..."
sleep 10

# Check health
if docker compose exec -T mongodb mongosh --eval "db.adminCommand('ping').ok" --quiet > /dev/null 2>&1; then
  echo -e "${GREEN}✅ MongoDB is running and healthy${NC}"
else
  echo -e "${RED}❌ MongoDB health check failed${NC}"
  echo "Check logs with: docker compose logs mongodb"
  exit 1
fi

# Display connection info
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "📊 MongoDB Information:"
echo "  - Container: q8-mongodb"
echo "  - Port: ${MONGO_PORT:-27017}"
echo "  - Data: ${MONGO_DATA_DIR:-/var/lib/mongodb}"
echo "  - Logs: ${MONGO_LOG_DIR:-/var/log/mongodb}"
echo "  - Backups: ${MONGO_BACKUP_DIR:-/var/backups/mongodb}"
echo ""
echo "🔗 Connection String:"
echo "  mongodb://${MONGO_USER}:<password>@localhost:${MONGO_PORT:-27017}/admin?authSource=admin"
echo ""
echo "📝 Next Steps:"
echo "  1. Create admin user: docker compose exec mongodb mongosh -u root -p"
echo "  2. Check logs: docker compose logs -f mongodb"
echo "  3. Check status: docker compose ps"
echo ""

