# Troubleshooting Guide

## Docker Permission Issues

### Error: `permission denied while trying to connect to the Docker daemon socket`

**Solution 1: Run with sudo (Quick Fix)**
```bash
sudo ./setup.sh
sudo docker compose logs mongodb
sudo docker compose ps
```

**Solution 2: Add User to Docker Group (Permanent Fix)**
```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Logout and login again (or restart terminal)
# Then verify:
docker info
```

**Solution 3: Use Docker Without Sudo (Alternative)**
```bash
# Change socket permissions (less secure, not recommended)
sudo chmod 666 /var/run/docker.sock
```

## MongoDB Health Check Failed

### Check Container Status
```bash
docker compose ps
# or with sudo:
sudo docker compose ps
```

### View Logs
```bash
docker compose logs mongodb
# or with sudo:
sudo docker compose logs mongodb

# Follow logs in real-time:
docker compose logs -f mongodb
```

### Common Issues

**1. MongoDB Not Starting**
- Check if port 27017 is already in use:
  ```bash
  sudo netstat -tlnp | grep 27017
  # or
  sudo lsof -i :27017
  ```
- Check disk space:
  ```bash
  df -h
  ```
- Check MongoDB logs for specific errors

**2. Permission Issues**
- Check directory permissions:
  ```bash
  ls -la /var/lib/mongodb
  ls -la /var/log/mongodb
  ```
- Ensure directories are owned by user 999 (MongoDB user):
  ```bash
  sudo chown -R 999:999 /var/lib/mongodb
  sudo chown -R 999:999 /var/log/mongodb
  ```

**3. Configuration Issues**
- Verify mongod.conf is valid:
  ```bash
  docker compose exec mongodb mongod --config /etc/mongod.conf --test
  ```
- Check environment variables:
  ```bash
  docker compose exec mongodb env | grep MONGO
  ```

**4. Memory/CPU Limits**
- If you have limited resources, reduce limits in `.env`:
  ```bash
  MONGO_MEMORY_LIMIT=16G
  MONGO_CPU_LIMIT=4
  MONGO_MEMORY_RESERVATION=8G
  MONGO_CPU_RESERVATION=1
  ```

## Connection Issues

### Cannot Connect to MongoDB

**Test Connection Locally:**
```bash
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"
```

**Test Connection from Host:**
```bash
mongosh "mongodb://root:password@localhost:27017/admin?authSource=admin"
```

**Check if MongoDB is Listening:**
```bash
docker compose exec mongodb netstat -tlnp | grep 27017
```

## Container Issues

### Container Keeps Restarting
```bash
# Check restart count
docker compose ps

# Check why it's restarting
docker compose logs --tail=50 mongodb

# Check container events
docker compose events mongodb
```

### Remove and Recreate Container
```bash
docker compose down
docker compose up -d
```

### Reset Everything (⚠️ Deletes Data)
```bash
docker compose down -v
sudo rm -rf /var/lib/mongodb/*
sudo rm -rf /var/log/mongodb/*
./setup.sh
```

## Performance Issues

### High Memory Usage
- Check current usage:
  ```bash
  docker stats q8-mongodb
  ```
- Reduce cache size in `.env`:
  ```bash
  MONGO_CACHE_SIZE_GB=8  # Instead of 32
  ```

### High CPU Usage
- Check current usage:
  ```bash
  docker stats q8-mongodb
  ```
- Reduce CPU limits in `.env`:
  ```bash
  MONGO_CPU_LIMIT=4  # Instead of 6
  ```

## Backup/Restore Issues

### Backup Fails
- Check backup directory permissions:
  ```bash
  ls -la /var/backups/mongodb
  sudo chmod 755 /var/backups/mongodb
  ```
- Check disk space:
  ```bash
  df -h /var/backups/mongodb
  ```

### Restore Fails
- Verify backup file exists and is readable
- Check MongoDB is running
- Ensure you have enough disk space

## Network Issues

### Cannot Connect from Other Servers
- Check firewall:
  ```bash
  sudo ufw status
  sudo ufw allow 27017/tcp
  ```
- Verify MongoDB is bound to correct IP:
  ```bash
  docker compose exec mongodb netstat -tlnp
  ```
- Check docker-compose.yml port mapping

## Getting Help

If issues persist:
1. Collect logs: `docker compose logs mongodb > mongodb-logs.txt`
2. Check system resources: `docker stats q8-mongodb`
3. Verify configuration: `cat .env` and `cat mongod.conf`
4. Check MongoDB version: `docker compose exec mongodb mongod --version`

