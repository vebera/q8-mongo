# Q8 MongoDB Production Server

Production-ready MongoDB server configuration for hosting all Q8 tenant databases.

## Architecture

- **Single MongoDB instance** serving multiple tenant databases
- **Database per tenant**: `q8_tenant_{tenantId}`
- **Docker-based deployment** for easy management
- **Automated backups** with retention policy
- **Production security** with authentication and encryption

## Server Requirements

### Recommended: CCX43 (Production)
- **vCPU**: 12 cores (AMD EPYC)
- **RAM**: 48GB
- **Storage**: 480GB NVMe SSD
- **Price**: ~€90/month
- **Capacity**: 30-50 tenant databases

### Alternative: CCX53 (Scale)
- **vCPU**: 16 cores
- **RAM**: 64GB
- **Storage**: 960GB NVMe SSD
- **Price**: ~€130/month
- **Capacity**: 50-100 tenant databases

## Quick Start

### 1. Prerequisites

- Docker and Docker Compose installed
- Server with recommended specs (CCX43 or CCX53)
- Root or sudo access
- **Note:** All `docker compose` commands require `sudo` unless your user is in the docker group

### 2. Initial Setup

```bash
# Clone or navigate to this directory
cd q8-mongo

# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env

# Generate MongoDB root password (use strong password)
openssl rand -base64 32

# Start MongoDB
sudo docker compose up -d

# Check status
sudo docker compose ps
sudo docker compose logs -f mongodb
```

### 3. Create Admin User

```bash
# Connect to MongoDB
sudo docker compose exec mongodb mongosh -u root -p

# In MongoDB shell, create admin user
use admin
db.createUser({
  user: "admin",
  pwd: "your-strong-password",
  roles: [{ role: "root", db: "admin" }]
})
```

### 4. Set Up Private Network (Recommended)

For production, set up a Hetzner Private Network so servers communicate securely:

See [HETZNER_PRIVATE_NETWORK.md](HETZNER_PRIVATE_NETWORK.md) for detailed instructions.

**Quick Setup:**
1. Create private network in Hetzner Cloud Console
2. Attach MongoDB server and tenant servers to network
3. Use private IPs (e.g., `10.0.0.10`) instead of public IPs

### 5. Verify Connection

```bash
# Test connection from tenant server (using private IP)
mongosh "mongodb://admin:password@10.0.0.10:27017/admin?authSource=admin"

# Or using hostname (if configured in /etc/hosts)
mongosh "mongodb://admin:password@mongodb-server:27017/admin?authSource=admin"
```

## Configuration

### Environment Variables

Edit `.env` file with your settings:

```bash
# MongoDB Configuration
MONGO_USER=root
MONGO_PASSWORD=your-strong-password-here
MONGO_PORT=27017

# WiredTiger Cache (60-70% of available RAM)
# For CCX43 (48GB RAM): 32GB
# For CCX53 (64GB RAM): 40GB
MONGO_CACHE_SIZE_GB=32

# Storage Paths
# Production volume mounted at /mnt/volume-db-prod
MONGO_DATA_DIR=/mnt/volume-db-prod/mongodb
MONGO_CONFIG_DIR=/mnt/volume-db-prod/mongodb-config
MONGO_LOG_DIR=/mnt/volume-db-prod/mongodb-logs
MONGO_BACKUP_DIR=/mnt/volume-db-prod/mongodb-backups

# Backup Configuration
BACKUP_RETENTION_DAYS=7
BACKUP_SCHEDULE="0 2 * * *"  # Daily at 2 AM

# Security
MONGO_KEYFILE_PATH=/etc/mongodb/mongodb-keyfile
```

### MongoDB Configuration

The `mongod.conf` file is optimized for production:
- WiredTiger storage engine
- Optimized cache size
- Log rotation
- Security settings
- Performance tuning

## Storage Management

### Storage Requirements

**Per Tenant Database:**
- Average: ~10GB per tenant
- Growth: 15-25GB after 12 months

**Total Storage Calculation:**
- 10 tenants: ~250-300GB (with backups)
- 30 tenants: ~750-800GB (with backups)
- 50 tenants: ~1.2-1.5TB (with backups)

### Using a Separate Mounted Volume

If your server has a separate mounted volume (common in Hetzner servers), configure MongoDB to use it:

**1. Verify your mounted volume:**
```bash
# List mounted filesystems
df -h

# Verify /mnt/volume-db-prod is mounted
mount | grep volume-db-prod
ls -la /mnt/volume-db-prod
```

**2. Create directories on the mounted volume:**
```bash
# Create directories on /mnt/volume-db-prod
sudo mkdir -p /mnt/volume-db-prod/mongodb
sudo mkdir -p /mnt/volume-db-prod/mongodb-config
sudo mkdir -p /mnt/volume-db-prod/mongodb-logs
sudo mkdir -p /mnt/volume-db-prod/mongodb-backups

# Set proper permissions (MongoDB runs as user 999)
sudo chown -R 999:999 /mnt/volume-db-prod/mongodb
sudo chown -R 999:999 /mnt/volume-db-prod/mongodb-config
sudo chown -R 999:999 /mnt/volume-db-prod/mongodb-logs
sudo chown -R 999:999 /mnt/volume-db-prod/mongodb-backups
```

**3. Update `.env` file:**
```bash
# Edit .env file
nano .env

# Set paths to your mounted volume
MONGO_DATA_DIR=/mnt/volume-db-prod/mongodb
MONGO_CONFIG_DIR=/mnt/volume-db-prod/mongodb-config
MONGO_LOG_DIR=/mnt/volume-db-prod/mongodb-logs
MONGO_BACKUP_DIR=/mnt/volume-db-prod/mongodb-backups
```

**4. Restart MongoDB:**
```bash
sudo docker compose down
sudo docker compose up -d
```

**Note:** The `docker-compose.yml` uses bind mounts, so it will automatically use the paths specified in your `.env` file.

### Storage Monitoring

Monitor disk usage regularly:

```bash
# Check disk usage
df -h

# Check MongoDB data directory size
du -sh ${MONGO_DATA_DIR:-/mnt/volume-db-prod/mongodb}

# Check backup directory size
du -sh ${MONGO_BACKUP_DIR:-/mnt/volume-db-prod/mongodb-backups}
```

**Alert Thresholds:**
- Disk usage > 80% → Plan upgrade
- Disk usage > 90% → Urgent action needed

## Backup & Recovery

### Automated Backups

Backups run daily at 2 AM (configurable via `BACKUP_SCHEDULE`).

**Backup Location:** `/mnt/volume-db-prod/mongodb-backups/`

**Backup Retention:** 7 days (configurable via `BACKUP_RETENTION_DAYS`)

### Manual Backup

```bash
# Backup all databases
docker compose exec mongodb mongodump --out /backup/$(date +%Y%m%d)

# Backup specific tenant database
docker compose exec mongodb mongodump \
  --db q8_tenant_{tenantId} \
  --out /backup/tenant-{tenantId}-$(date +%Y%m%d)
```

### Restore from Backup

```bash
# Restore all databases
docker compose exec mongodb mongorestore /backup/20240101

# Restore specific tenant database
docker compose exec mongodb mongorestore \
  --db q8_tenant_{tenantId} \
  /backup/tenant-{tenantId}-20240101
```

## Tenant Database Management

### Create Tenant Database

```bash
# Connect to MongoDB
docker compose exec mongodb mongosh -u admin -p

# Create database and user for tenant
use q8_tenant_{tenantId}
db.createUser({
  user: "tenant_{tenantId}",
  pwd: "tenant-password",
  roles: [{ role: "readWrite", db: "q8_tenant_{tenantId}" }]
})
```

### Connection String for Tenant

**Using Private Network (Recommended):**
```
mongodb://tenant_{tenantId}:password@10.0.0.10:27017/q8_tenant_{tenantId}?authSource=q8_tenant_{tenantId}
```

**Using Hostname (if /etc/hosts configured):**
```
mongodb://tenant_{tenantId}:password@mongodb-server:27017/q8_tenant_{tenantId}?authSource=q8_tenant_{tenantId}
```

**Note:** Replace `10.0.0.10` with your MongoDB server's private IP address.

### List All Tenant Databases

```bash
docker compose exec mongodb mongosh -u admin -p --eval "db.adminCommand('listDatabases')"
```

## Monitoring

### Health Check

```bash
# Check MongoDB status
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Check server status
docker compose exec mongodb mongosh --eval "db.serverStatus()"
```

### Key Metrics to Monitor

- **Memory Usage**: WiredTiger cache usage
- **Disk Usage**: Data directory and backup directory
- **Connection Count**: Active connections
- **Query Performance**: Slow queries
- **Replication Lag**: If using replica set

### Logs

```bash
# View MongoDB logs
docker compose logs -f mongodb

# View recent logs
docker compose logs --tail=100 mongodb

# View error logs only
docker compose logs mongodb | grep -i error
```

## Security

### Best Practices

1. **Strong Passwords**: Use complex passwords for all users
2. **Network Security**: Only allow connections from tenant servers (firewall)
3. **Authentication**: Always use authentication (enabled by default)
4. **Keyfile**: Replica set keyfile for internal authentication
5. **Backup Encryption**: Encrypt backups if storing sensitive data
6. **Regular Updates**: Keep MongoDB updated to latest stable version

### Firewall Configuration

```bash
# Allow only tenant servers (example)
ufw allow from 10.0.0.0/8 to any port 27017
ufw deny 27017
```

## Maintenance

### Update MongoDB

```bash
# Pull latest image
docker compose pull mongodb

# Restart with new image
docker compose up -d mongodb
```

### Cleanup Old Data

```bash
# Clean old backups (keep last 7 days)
find /mnt/volume-db-prod/mongodb-backups -type d -mtime +7 -exec rm -rf {} \;

# Clean MongoDB logs (handled by log rotation)
```

### Performance Tuning

Edit `mongod.conf` to adjust:
- `wiredTiger.engineConfig.cacheSizeGB` - Memory cache size
- `operationProfiling.slowOpThresholdMs` - Slow query threshold
- `net.maxIncomingConnections` - Max connections

## Troubleshooting

### MongoDB Won't Start

```bash
# Check logs
docker compose logs mongodb

# Check disk space
df -h

# Check permissions
ls -la /mnt/volume-db-prod/mongodb
```

### High Memory Usage

```bash
# Check cache size
docker compose exec mongodb mongosh --eval "db.serverStatus().wiredTiger.cache"

# Reduce cache size in mongod.conf if needed
```

### Connection Issues

```bash
# Test connection
mongosh "mongodb://user:password@host:27017/db"

# Check firewall
ufw status

# Check MongoDB is listening
netstat -tlnp | grep 27017
```

## Scaling

### When to Upgrade

- **RAM usage > 80%**: Upgrade to larger server
- **Disk usage > 80%**: Add storage or upgrade
- **CPU usage > 70%**: Upgrade to more CPU cores
- **30+ tenants**: Consider CCX53 (64GB RAM)

### Upgrade Path

1. **CCX43 → CCX53**: 
   - Create snapshot
   - Resize server in Hetzner
   - Update `MONGO_CACHE_SIZE_GB=40` in `.env`
   - Restart MongoDB

2. **Add External Volume**:
   - Add Hetzner volume for backups
   - Mount to `/var/backups/mongodb`

## Support

For issues or questions:
- Check logs: `docker compose logs mongodb`
- Review configuration: `mongod.conf`
- Check storage: `df -h` and `du -sh /mnt/volume-db-prod/mongodb`

## Network Setup

For production deployments, set up a Hetzner Private Network for secure server-to-server communication:

📖 **See [HETZNER_PRIVATE_NETWORK.md](HETZNER_PRIVATE_NETWORK.md) for complete setup guide**

**Benefits:**
- ✅ Secure private communication
- ✅ No data transfer costs
- ✅ Lower latency
- ✅ Better performance

## References

- [Hetzner Private Network Setup](HETZNER_PRIVATE_NETWORK.md)
- [MongoDB Production Notes](https://docs.mongodb.com/manual/administration/production-notes/)
- [WiredTiger Configuration](https://docs.mongodb.com/manual/core/wiredtiger/)
- [Security Checklist](https://docs.mongodb.com/manual/administration/security-checklist/)
