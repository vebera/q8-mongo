# Hetzner Private Network Setup Guide

This guide explains how to set up a private network in Hetzner Cloud so all your servers can communicate securely without using public IPs.

## Why Private Network?

- ✅ **Security**: Servers communicate privately, not exposed to internet
- ✅ **Performance**: Lower latency, higher bandwidth
- ✅ **Cost**: No data transfer costs for internal traffic
- ✅ **Isolation**: Separate from public network

## Step 1: Create Private Network

### Via Hetzner Cloud Console

1. **Login** to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. **Navigate** to your project
3. **Go to** "Networks" in the left sidebar
4. **Click** "Add Network" button
5. **Configure Network**:
   - **Name**: `q8-internal-network` (or your preferred name)
   - **IP Range**: `10.0.0.0/16` (recommended, provides 65,536 IPs)
     - Alternative: `10.0.0.0/24` (256 IPs) for smaller setups
   - **Network Zone**: Choose your primary datacenter (e.g., `nbg1`, `fsn1`, `hel1`)
   - **Subnet**: Leave default or customize
6. **Click** "Create Network"

### Via Hetzner CLI (hcloud)

```bash
# Install hcloud CLI if not installed
# macOS: brew install hcloud
# Linux: See https://github.com/hetznercloud/cli

# Login
hcloud context create q8-project

# Create network
hcloud network create \
  --name q8-internal-network \
  --ip-range 10.0.0.0/16 \
  --location nbg1
```

## Step 2: Attach Servers to Network

### Via Hetzner Cloud Console

1. **Go to** "Servers" in the left sidebar
2. **Click** on a server (e.g., MongoDB server)
3. **Go to** "Networks" tab
4. **Click** "Attach to Network"
5. **Select** your private network (`q8-internal-network`)
6. **Assign IP** (optional, or use auto-assigned):
   - MongoDB Server: `10.0.0.10`
   - Tenant Server #1: `10.0.0.20`
   - Tenant Server #2: `10.0.0.30`
   - etc.
7. **Click** "Attach"
8. **Repeat** for all servers

### Via Hetzner CLI

```bash
# Attach MongoDB server to network
hcloud server attach-to-network mongodb-server \
  --network q8-internal-network \
  --ip 10.0.0.10

# Attach Tenant Server #1
hcloud server attach-to-network tenant-server-1 \
  --network q8-internal-network \
  --ip 10.0.0.20

# Attach Tenant Server #2
hcloud server attach-to-network tenant-server-2 \
  --network q8-internal-network \
  --ip 10.0.0.30
```

## Step 3: Configure Network on Servers

### On Each Server

After attaching to network, configure the network interface:

```bash
# SSH into server
ssh root@your-server-ip

# Install cloud-init if not present (usually pre-installed)
# For Ubuntu/Debian:
apt-get update && apt-get install -y cloud-init

# The network should be automatically configured by Hetzner
# Verify network interface
ip addr show

# You should see a new interface (usually eth1 or ens10)
# Example output:
# 3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
#     inet 10.0.0.10/16 brd 10.0.0.255 scope global eth1
```

### Manual Configuration (if auto-config doesn't work)

For Ubuntu/Debian with Netplan:

```bash
# Edit netplan config
nano /etc/netplan/50-cloud-init.yaml

# Add private network configuration:
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      # Public network
    eth1:
      dhcp4: false
      addresses:
        - 10.0.0.10/16  # Your assigned private IP
      routes:
        - to: 10.0.0.0/16
          via: 10.0.0.1  # Network gateway
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

# Apply configuration
netplan apply
```

For CentOS/RHEL:

```bash
# Create network interface config
nano /etc/sysconfig/network-scripts/ifcfg-eth1

# Add:
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=10.0.0.10
NETMASK=255.255.0.0
GATEWAY=10.0.0.1

# Restart network
systemctl restart network
```

## Step 4: Configure Firewall

### Allow Private Network Traffic

On each server, configure firewall to allow private network:

```bash
# Ubuntu/Debian (UFW)
ufw allow from 10.0.0.0/16 to any port 27017  # MongoDB
ufw allow from 10.0.0.0/16 to any port 22      # SSH (optional)
ufw allow from 10.0.0.0/16                     # All traffic from private network

# Verify rules
ufw status numbered
```

### MongoDB Server Specific

On MongoDB server, restrict MongoDB to private network only:

```bash
# Allow MongoDB only from private network
ufw allow from 10.0.0.0/16 to any port 27017

# Deny MongoDB from public internet (if you want extra security)
# Note: This means you can only access MongoDB from other servers in the network
ufw deny 27017
```

## Step 5: Update MongoDB Configuration

### Update docker-compose.yml

Edit the MongoDB `docker-compose.yml` to bind to private network:

```yaml
services:
  mongodb:
    # ... other config ...
    ports:
      # Remove public port or keep for admin access
      # Option 1: Only private network (recommended)
      # No ports section, use internal Docker network
      
      # Option 2: Keep public port for admin access (less secure)
      - "127.0.0.1:27017:27017"  # Only accessible from localhost
```

### Update Connection Strings

Update tenant server connection strings to use private IP:

**Before (Public IP):**
```
mongodb://user:password@123.45.67.89:27017/q8_tenant_{tenantId}?authSource=admin
```

**After (Private IP):**
```
mongodb://user:password@10.0.0.10:27017/q8_tenant_{tenantId}?authSource=admin
```

Or use hostname if you set up DNS:

```
mongodb://user:password@mongodb-server.private:27017/q8_tenant_{tenantId}?authSource=admin
```

## Step 6: Test Connectivity

### From Tenant Server to MongoDB

```bash
# SSH into tenant server
ssh root@tenant-server-ip

# Test connectivity
ping 10.0.0.10  # MongoDB private IP

# Test MongoDB connection
mongosh "mongodb://user:password@10.0.0.10:27017/admin?authSource=admin"

# Or using telnet
telnet 10.0.0.10 27017
```

### From MongoDB Server

```bash
# SSH into MongoDB server
ssh root@mongodb-server-ip

# Test connectivity to tenant servers
ping 10.0.0.20  # Tenant Server #1
ping 10.0.0.30  # Tenant Server #2
```

## Step 7: Set Up Hostnames (Optional)

For easier management, add hostnames to `/etc/hosts` on each server:

```bash
# On MongoDB server
nano /etc/hosts

# Add:
10.0.0.20  tenant-server-1
10.0.0.30  tenant-server-2

# On Tenant Server #1
nano /etc/hosts

# Add:
10.0.0.10  mongodb-server
10.0.0.30  tenant-server-2

# On Tenant Server #2
nano /etc/hosts

# Add:
10.0.0.10  mongodb-server
10.0.0.20  tenant-server-1
```

Now you can use hostnames in connection strings:

```
mongodb://user:password@mongodb-server:27017/q8_tenant_{tenantId}?authSource=admin
```

## Network IP Allocation Plan

Recommended IP allocation:

```
10.0.0.1    - Network Gateway
10.0.0.10   - MongoDB Server
10.0.0.20   - Tenant Server #1
10.0.0.30   - Tenant Server #2
10.0.0.40   - Tenant Server #3
10.0.0.50   - Tenant Server #4
10.0.0.60   - Tenant Server #5
...
10.0.0.100  - Reserved for future use
10.0.0.200  - Reserved for monitoring/logging
10.0.0.250  - Reserved for admin tools
```

## Troubleshooting

### Server Can't See Other Servers

```bash
# Check if network interface exists
ip addr show

# Check routing
ip route show

# Check firewall
ufw status

# Test connectivity
ping 10.0.0.10
```

### MongoDB Connection Refused

```bash
# Check if MongoDB is listening on private IP
netstat -tlnp | grep 27017

# Check MongoDB bind configuration
docker compose exec mongodb cat /etc/mongod.conf | grep bindIp

# Test from MongoDB server itself
mongosh "mongodb://localhost:27017"
```

### Network Interface Not Appearing

```bash
# Check if network is attached in Hetzner Console
# Reboot server (network should auto-configure)
reboot

# Or manually configure (see Step 3)
```

## Security Best Practices

1. **Firewall Rules**: Only allow necessary ports from private network
2. **MongoDB Binding**: Bind MongoDB to private IP only
3. **Strong Passwords**: Use strong passwords even on private network
4. **Network Isolation**: Keep private network separate from public
5. **Monitoring**: Monitor network traffic for anomalies

## Cost

**Private Networks in Hetzner Cloud are FREE!** ✅

- No additional cost for private network
- No data transfer costs for internal traffic
- Only pay for servers

## Next Steps

1. ✅ Create private network
2. ✅ Attach all servers
3. ✅ Configure firewall rules
4. ✅ Update MongoDB connection strings
5. ✅ Test connectivity
6. ✅ Update tenant server configurations

## References

- [Hetzner Private Networks Documentation](https://docs.hetzner.com/cloud/networks/overview/)
- [Hetzner CLI Documentation](https://github.com/hetznercloud/cli)

