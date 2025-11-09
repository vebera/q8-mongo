# Quick Start Guide

## 1. Initial Setup (One-Time)

```bash
# Clone or navigate to directory
cd q8-mongo

# Run setup script (requires sudo/root)
sudo ./setup.sh
```

The setup script will:
- Create necessary directories
- Generate MongoDB keyfile
- Start MongoDB container
- Verify health

## 2. Configure Environment

Edit `.env` file:

```bash
nano .env
```

**Required changes:**
- Set `MONGO_PASSWORD` to a strong password
- Adjust `MONGO_CACHE_SIZE_GB` based on your server RAM:
  - CCX43 (48GB): `32`
  - CCX53 (64GB): `40`

## 3. Create Admin User

```bash
# Connect to MongoDB
docker compose exec mongodb mongosh -u root -p

# In MongoDB shell:
use admin
db.createUser({
  user: "admin",
  pwd: "your-strong-password",
  roles: [{ role: "root", db: "admin" }]
})
exit
```

## 4. Create Tenant Database

```bash
# Connect as admin
docker compose exec mongodb mongosh -u admin -p

# Create tenant database and user
use q8_tenant_{tenantId}
db.createUser({
  user: "tenant_{tenantId}",
  pwd: "tenant-password",
  roles: [{ role: "readWrite", db: "q8_tenant_{tenantId}" }]
})
```

## 5. Test Connection

From tenant server, test connection:

```bash
mongosh "mongodb://tenant_{tenantId}:password@mongodb-server-ip:27017/q8_tenant_{tenantId}?authSource=q8_tenant_{tenantId}"
```

## Common Commands

```bash
# View logs
docker compose logs -f mongodb

# Check status
docker compose ps

# Stop MongoDB
docker compose down

# Start MongoDB
docker compose up -d

# Backup all databases
./backup.sh all

# Backup specific tenant
./backup.sh tenant {tenantId}

# Restore from backup
./restore.sh full_20240101_020000.tar.gz

# List backups
./backup.sh list
```

## Troubleshooting

**MongoDB won't start:**
```bash
# Check logs
docker compose logs mongodb

# Check disk space
df -h

# Check permissions
ls -la /var/lib/mongodb
```

**Connection refused:**
```bash
# Check if MongoDB is running
docker compose ps

# Check firewall
ufw status

# Test connection locally
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"
```

## Next Steps

- Set up automated backups (cron job)
- Configure monitoring
- Set up firewall rules
- Review security settings

See [README.md](README.md) for detailed documentation.

