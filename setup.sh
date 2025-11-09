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
  
  if [ ! -f .env.example ]; then
    echo -e "${RED}❌ .env.example file not found${NC}"
    exit 1
  fi
  
  cp .env.example .env
  
  # Generate unique secrets
  echo "🔑 Generating unique secret keys..."
  
  # Detect sed command (macOS vs Linux)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_INPLACE="sed -i ''"
  else
    SED_INPLACE="sed -i"
  fi
  
  # Use perl for more reliable replacement (fallback to sed if perl not available)
  USE_PERL=false
  if command -v perl &> /dev/null; then
    USE_PERL=true
  fi
  
  # Helper function to replace placeholder in .env file
  replace_placeholder() {
    local placeholder=$1
    local value=$2
    
    # Quote the value to prevent bash from interpreting special chars when sourcing
    # This ensures values with $, !, `, etc. are safely handled
    local quoted_value="\"${value}\""
    
    if [ "$USE_PERL" = true ]; then
      # Use perl with environment variables to avoid quote escaping issues
      PLACEHOLDER_VAR="${placeholder}" REPLACEMENT_VAR="${quoted_value}" perl -i -pe '
        $ph = $ENV{PLACEHOLDER_VAR};
        $rep = $ENV{REPLACEMENT_VAR};
        s/\{$ph\}/$rep/g;
      ' .env
    else
      # Escape special characters for sed, including quotes and backslashes
      # Escape backslashes first, then other special chars, then quotes
      ESCAPED_VALUE=$(printf '%s\n' "$quoted_value" | \
        sed 's/\\/\\\\/g' | \
        sed 's/[[\.*^$()+?{|]/\\&/g' | \
        sed 's/"/\\"/g')
      $SED_INPLACE "s/{${placeholder}}/${ESCAPED_VALUE}/g" .env
    fi
  }
  
  # Generate and replace MongoDB credentials
  echo "🔑 Generating MongoDB credentials..."
  MONGO_USER="root"
  replace_placeholder "MONGO_USER" "$MONGO_USER"
  
  MONGO_PASSWORD=$(openssl rand -base64 32 | tr -d '\n\r')
  replace_placeholder "MONGO_PASSWORD" "$MONGO_PASSWORD"
  
  echo "🔑 Generating MongoDB Express credentials..."
  MONGO_EXPRESS_USER="admin"
  replace_placeholder "MONGO_EXPRESS_USER" "$MONGO_EXPRESS_USER"
  
  MONGO_EXPRESS_PASSWORD=$(openssl rand -base64 24 | tr -d '\n\r')
  replace_placeholder "MONGO_EXPRESS_PASSWORD" "$MONGO_EXPRESS_PASSWORD"
  
  # Replace any placeholders enclosed in { and }
  echo "🔄 Replacing remaining placeholders..."
  
  # Generate unique values for common placeholders
  # Replace {random} with random string
  while grep -q '{random}' .env; do
    RANDOM_STR=$(openssl rand -hex 16)
    if [ "$USE_PERL" = true ]; then
      perl -pi -e "s/\{random\}/${RANDOM_STR}/g" .env
    else
      $SED_INPLACE "s/{random}/${RANDOM_STR}/g" .env
    fi
  done
  
  # Replace {timestamp} with current timestamp
  while grep -q '{timestamp}' .env; do
    TIMESTAMP=$(date +%s)
    if [ "$USE_PERL" = true ]; then
      perl -pi -e "s/\{timestamp\}/${TIMESTAMP}/g" .env
    else
      $SED_INPLACE "s/{timestamp}/${TIMESTAMP}/g" .env
    fi
  done
  
  # Replace {uuid} with UUID
  while grep -q '{uuid}' .env; do
    UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
    if [ "$USE_PERL" = true ]; then
      perl -pi -e "s/\{uuid\}/${UUID}/g" .env
    else
      $SED_INPLACE "s/{uuid}/${UUID}/g" .env
    fi
  done
  
  # Replace any other {placeholder} patterns with generated secrets
  # This catches any remaining {something} patterns
  while grep -qE '\{[^}]+\}' .env; do
    # Extract placeholder name
    PLACEHOLDER=$(grep -oE '\{[^}]+\}' .env | head -1)
    # Generate secret for it
    SECRET=$(openssl rand -hex 32)
    if [ "$USE_PERL" = true ]; then
      # Use perl for replacement (handles special chars better)
      perl -pi -e "s/\Q${PLACEHOLDER}\E/${SECRET}/g" .env
    else
      # Fallback to sed (may have issues with special chars)
      PLACEHOLDER_NAME=$(echo "$PLACEHOLDER" | tr -d '{}')
      $SED_INPLACE "s/${PLACEHOLDER}/${SECRET}/g" .env
    fi
  done
  
  echo -e "${GREEN}✅ Created .env file with generated secrets${NC}"
  echo -e "${YELLOW}⚠️  IMPORTANT: Save the generated passwords securely!${NC}"
  echo ""
  
  # Display generated credentials
  echo "📋 Generated Credentials:"
  echo "  MONGO_USER: ${MONGO_USER}"
  echo "  MONGO_PASSWORD: ${MONGO_PASSWORD}"
  echo "  MONGO_EXPRESS_USER: ${MONGO_EXPRESS_USER}"
  echo "  MONGO_EXPRESS_PASSWORD: ${MONGO_EXPRESS_PASSWORD}"
  echo ""
  echo -e "${YELLOW}💡 These credentials are saved in .env file. Keep it secure!${NC}"
  echo ""
  read -p "Press Enter to continue with setup..."
fi

# Source environment variables
# Values are quoted in .env file to handle special characters safely
set -a
if [ -f .env ]; then
  # Source .env file - quoted values will be handled correctly by bash
  # Suppress errors from special characters that might be misinterpreted
  set +e
  source .env 2>/dev/null
  set -e
fi
set +a

# Create directories
echo "📁 Creating directories..."
mkdir -p "${MONGO_DATA_DIR:-/mnt/volume-db-prod/mongodb}"
mkdir -p "${MONGO_CONFIG_DIR:-/mnt/volume-db-prod/mongodb-config}"
mkdir -p "${MONGO_LOG_DIR:-/mnt/volume-db-prod/mongodb-logs}"
mkdir -p "${MONGO_BACKUP_DIR:-/mnt/volume-db-prod/mongodb-backups}"
mkdir -p config

# Set permissions
echo "🔐 Setting permissions..."
chown -R 999:999 "${MONGO_DATA_DIR:-/mnt/volume-db-prod/mongodb}"
chown -R 999:999 "${MONGO_CONFIG_DIR:-/mnt/volume-db-prod/mongodb-config}"
chown -R 999:999 "${MONGO_LOG_DIR:-/mnt/volume-db-prod/mongodb-logs}"
chown -R 999:999 "${MONGO_BACKUP_DIR:-/mnt/volume-db-prod/mongodb-backups}"
chmod 755 "${MONGO_BACKUP_DIR:-/mnt/volume-db-prod/mongodb-backups}"

# Generate MongoDB keyfile if it doesn't exist
if [ ! -f config/mongodb-keyfile ]; then
  echo "🔑 Generating MongoDB keyfile..."
  openssl rand -base64 756 > config/mongodb-keyfile
  chmod 400 config/mongodb-keyfile
  chown 999:999 config/mongodb-keyfile
  echo -e "${GREEN}✅ Generated MongoDB keyfile${NC}"
fi

# Check if there are any remaining placeholders
if grep -qE '\{[^}]+\}' .env; then
  echo -e "${YELLOW}⚠️  Warning: Found remaining placeholders in .env file${NC}"
  echo "The following placeholders were not replaced:"
  grep -oE '\{[^}]+\}' .env | sort -u
  echo ""
  read -p "Continue anyway? (y/N): " CONTINUE
  if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
    exit 1
  fi
fi

# Check if there are any remaining {placeholder} patterns (in case user manually edited)
if grep -qE '\{[^}]+\}' .env; then
  echo -e "${YELLOW}⚠️  Found remaining placeholders in .env file${NC}"
  echo -e "${YELLOW}💡 Generating missing secrets...${NC}"
  
  # Detect sed command (macOS vs Linux)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_INPLACE="sed -i ''"
  else
    SED_INPLACE="sed -i"
  fi
  
  # Use perl if available
  USE_PERL=false
  if command -v perl &> /dev/null; then
    USE_PERL=true
  fi
  
  # Helper function to replace placeholder in .env file
  replace_placeholder() {
    local placeholder=$1
    local value=$2
    
    # Quote the value to prevent bash from interpreting special chars when sourcing
    # This ensures values with $, !, `, etc. are safely handled
    local quoted_value="\"${value}\""
    
    if [ "$USE_PERL" = true ]; then
      # Use perl with environment variables to avoid quote escaping issues
      PLACEHOLDER_VAR="${placeholder}" REPLACEMENT_VAR="${quoted_value}" perl -i -pe '
        $ph = $ENV{PLACEHOLDER_VAR};
        $rep = $ENV{REPLACEMENT_VAR};
        s/\{$ph\}/$rep/g;
      ' .env
    else
      # Escape special characters for sed, including quotes and backslashes
      # Escape backslashes first, then other special chars, then quotes
      ESCAPED_VALUE=$(printf '%s\n' "$quoted_value" | \
        sed 's/\\/\\\\/g' | \
        sed 's/[[\.*^$()+?{|]/\\&/g' | \
        sed 's/"/\\"/g')
      $SED_INPLACE "s/{${placeholder}}/${ESCAPED_VALUE}/g" .env
    fi
  }
  
  # Generate MongoDB user if still has placeholder
  if grep -qE "MONGO_USER=\{MONGO_USER\}|MONGO_USER=.*\{.*\}" .env; then
    MONGO_USER="root"
    replace_placeholder "MONGO_USER" "$MONGO_USER"
    echo -e "${GREEN}✅ Generated MONGO_USER${NC}"
  fi
  
  # Generate MongoDB password if still has placeholder
  if grep -qE "MONGO_PASSWORD=\{MONGO_PASSWORD\}|MONGO_PASSWORD=.*\{.*\}" .env; then
    MONGO_PASSWORD=$(openssl rand -base64 32 | tr -d '\n\r')
    replace_placeholder "MONGO_PASSWORD" "$MONGO_PASSWORD"
    echo -e "${GREEN}✅ Generated MONGO_PASSWORD${NC}"
  fi
  
  # Generate MongoDB Express user if still has placeholder
  if grep -qE "MONGO_EXPRESS_USER=\{MONGO_EXPRESS_USER\}|MONGO_EXPRESS_USER=.*\{.*\}" .env; then
    MONGO_EXPRESS_USER="admin"
    replace_placeholder "MONGO_EXPRESS_USER" "$MONGO_EXPRESS_USER"
    echo -e "${GREEN}✅ Generated MONGO_EXPRESS_USER${NC}"
  fi
  
  # Generate MongoDB Express password if still has placeholder
  if grep -qE "MONGO_EXPRESS_PASSWORD=\{MONGO_EXPRESS_PASSWORD\}|MONGO_EXPRESS_PASSWORD=.*\{.*\}" .env; then
    MONGO_EXPRESS_PASSWORD=$(openssl rand -base64 24 | tr -d '\n\r')
    replace_placeholder "MONGO_EXPRESS_PASSWORD" "$MONGO_EXPRESS_PASSWORD"
    echo -e "${GREEN}✅ Generated MONGO_EXPRESS_PASSWORD${NC}"
  fi
  
  # Replace any other remaining placeholders
  while grep -qE '\{[^}]+\}' .env; do
    PLACEHOLDER=$(grep -oE '\{[^}]+\}' .env | head -1)
    SECRET=$(openssl rand -hex 32)
    if [ "$USE_PERL" = true ]; then
      perl -pi -e "s/\Q${PLACEHOLDER}\E/${SECRET}/g" .env
    else
      PLACEHOLDER_NAME=$(echo "$PLACEHOLDER" | tr -d '{}')
      $SED_INPLACE "s/${PLACEHOLDER}/${SECRET}/g" .env
    fi
  done
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

# Check Docker permissions
if ! docker info &> /dev/null; then
  echo -e "${YELLOW}⚠️  Docker permission issue detected${NC}"
  echo -e "${YELLOW}💡 You need to either:${NC}"
  echo "   1. Run this script with sudo: sudo ./setup.sh"
  echo "   2. Add your user to docker group: sudo usermod -aG docker $USER"
  echo "      (then logout and login again)"
  echo ""
  read -p "Continue anyway? (y/N): " CONTINUE
  if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
    exit 1
  fi
fi

# Start MongoDB
echo "🐳 Starting MongoDB container..."

# Check if we need sudo for docker
DOCKER_CMD="docker compose"
if ! docker info &> /dev/null 2>&1; then
  if sudo docker info &> /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Using sudo for Docker commands${NC}"
    DOCKER_CMD="sudo docker compose"
  else
    echo -e "${RED}❌ Cannot access Docker. Please fix permissions or run with sudo${NC}"
    exit 1
  fi
fi

$DOCKER_CMD up -d

# Wait for MongoDB to be ready (it needs time to initialize)
echo "⏳ Waiting for MongoDB to be ready (this may take 30-60 seconds)..."
sleep 15

# Try health check with retries
MAX_RETRIES=6
RETRY_COUNT=0
HEALTHY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if $DOCKER_CMD exec -T mongodb mongosh --eval "db.adminCommand('ping').ok" --quiet > /dev/null 2>&1; then
    HEALTHY=true
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "  Attempt $RETRY_COUNT/$MAX_RETRIES - MongoDB not ready yet, waiting..."
  sleep 10
done

if [ "$HEALTHY" = true ]; then
  echo -e "${GREEN}✅ MongoDB is running and healthy${NC}"
else
  echo -e "${RED}❌ MongoDB health check failed after ${MAX_RETRIES} attempts${NC}"
  echo ""
  echo "📋 Troubleshooting steps:"
  echo "  1. Check logs: $DOCKER_CMD logs mongodb"
  echo "  2. Check container status: $DOCKER_CMD ps"
  echo "  3. Check if MongoDB is listening: $DOCKER_CMD exec mongodb mongosh --eval 'db.adminCommand(\"ping\")'"
  echo ""
  exit 1
fi

# Display connection info
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "📊 MongoDB Information:"
echo "  - Container: q8-mongodb"
echo "  - Port: ${MONGO_PORT:-27017}"
echo "  - Data: ${MONGO_DATA_DIR:-/mnt/volume-db-prod/mongodb}"
echo "  - Logs: ${MONGO_LOG_DIR:-/mnt/volume-db-prod/mongodb-logs}"
echo "  - Backups: ${MONGO_BACKUP_DIR:-/mnt/volume-db-prod/mongodb-backups}"
echo ""
echo "🔗 Connection String:"
echo "  mongodb://${MONGO_USER}:<password>@localhost:${MONGO_PORT:-27017}/admin?authSource=admin"
echo ""
echo "📝 Next Steps:"
echo "  1. 🔒 CRITICAL: Configure firewall to restrict MongoDB to private network only:"
echo "     sudo ufw allow from 10.0.0.0/8 to any port ${MONGO_PORT:-27017} proto tcp"
echo "     See README.md for detailed firewall configuration"
echo "  2. Create admin user: $DOCKER_CMD exec mongodb mongosh -u root -p"
echo "  3. Check logs: $DOCKER_CMD logs -f mongodb"
echo "  4. Check status: $DOCKER_CMD ps"
echo ""
echo "⚠️  SECURITY REMINDER:"
echo "   MongoDB is configured to bind to 0.0.0.0 inside the container."
echo "   You MUST configure firewall rules on the host to restrict access"
echo "   to the private network (10.0.0.0/8) only. See README.md for details."
echo ""

