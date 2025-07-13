# 🚀 Setulab Automation - Installation Guide

Complete step-by-step installation guide for setting up Setulab automation on Linux systems.

## 📋 Table of Contents

1. [System Requirements](#system-requirements)
2. [Quick Installation](#quick-installation)
3. [Detailed Installation](#detailed-installation)
4. [Verification](#verification)
5. [First Steps](#first-steps)
6. [Troubleshooting](#troubleshooting)

## 💻 System Requirements

### Minimum Requirements
- **OS**: Linux (Ubuntu 18.04+, Debian 10+, CentOS 7+, Fedora 30+, Arch Linux)
- **RAM**: 2GB (4GB recommended)
- **Storage**: 10GB free space (20GB recommended)
- **Network**: Internet connection for downloading images

### Recommended Requirements
- **OS**: Ubuntu 22.04+ or Debian 11+
- **RAM**: 8GB or more
- **Storage**: 50GB+ free space
- **CPU**: 2+ cores

## ⚡ Quick Installation

For users who want to get started immediately:

```bash
# 1. Clone or download the project
git clone <repository-url> setulab
cd setulab/docker

# 2. Make scripts executable
chmod +x *.sh infra/*.sh monitoring/*.sh

# 3. Run prerequisite checker (installs Docker, Docker Compose, Task)
./prerequisite.sh

# 4. Start with a simple service
./setulab.sh setup infra postgres
./setulab.sh start infra postgres

# 5. Or use the full stack
task full:stack
```

That's it! 🎉 Your services will be available at their respective URLs.

## 📝 Detailed Installation

### Step 1: Download Setulab

#### Option A: Git Clone (Recommended)
```bash
git clone <repository-url> setulab
cd setulab/docker
```

#### Option B: Direct Download
```bash
# Download the release archive
wget <download-url> -O setulab.tar.gz
tar -xzf setulab.tar.gz
cd setulab/docker
```

#### Option C: Manual Setup
Create the directory structure and copy the files manually.

### Step 2: Make Scripts Executable

```bash
# Make all scripts executable
chmod +x *.sh infra/*.sh monitoring/*.sh

# Verify permissions
ls -la *.sh
```

### Step 3: Run Prerequisite Checker

The prerequisite checker will automatically detect your system and install required dependencies.

#### Automatic Installation (Recommended)
```bash
# Check and install all prerequisites
./prerequisite.sh
```

This will:
- Detect your Linux distribution
- Show system information
- Check for Docker, Docker Compose, and Task
- Offer to install missing components
- Configure permissions automatically

#### Manual Check Only
```bash
# Just check what's installed without installing anything
./prerequisite.sh --check-only
```

#### Force Reinstall
```bash
# Force reinstall all components
./prerequisite.sh --force
```

### Step 4: Verify Installation

```bash
# Check prerequisites
./setulab.sh prereq --check-only

# Show help to verify main script works
./setulab.sh help

# List available resources
./setulab.sh list infra
./setulab.sh list monitoring

# Test Task integration (if installed)
task --list
task help
```

## ✅ Verification

### Quick Health Check

```bash
# System information
./prerequisite.sh --check-only

# Docker verification
docker --version
docker info
docker ps

# Docker Compose verification
docker compose version

# Task verification (optional)
task --version
```

### Expected Output

You should see:
- ✅ Docker v20.10+ running
- ✅ Docker Compose v2.0+ available
- ✅ Task v3.0+ (optional)
- ✅ User has Docker permissions
- ✅ All scripts are executable

## 🎯 First Steps

### Option 1: Start with PostgreSQL

Perfect for testing the system:

```bash
# Setup and start PostgreSQL with PgAdmin
./setulab.sh setup infra postgres pg-admin
./setulab.sh start infra postgres pg-admin

# Or use Task shortcut
task postgres:start

# Access PgAdmin at http://localhost:15432
# Credentials: admin@pgadmin.com / password
```

### Option 2: Start with Monitoring

Great for system observability:

```bash
# Setup and start monitoring stack
./setulab.sh setup monitoring grafana prometheus dozzle
./setulab.sh start monitoring grafana prometheus dozzle

# Or use Task shortcut
task monitoring:start

# Access Grafana at http://localhost:3000
# Credentials: admin / admin
```

### Option 3: Full Development Stack

Everything you need for development:

```bash
# Setup and start everything
task full:stack

# This includes:
# - PostgreSQL + PgAdmin
# - RabbitMQ + Management UI
# - Redis + Redis Insight
# - MongoDB
# - Grafana + Prometheus
# - Dozzle (log viewer)
# - Loki (log aggregation)
```

### Check Service Status

```bash
# Check all services
./setulab.sh status infra
./setulab.sh status monitoring

# Or with Task
task status:all

# Health check
task health:check

# Show all service URLs
task docs:urls
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Permission Denied Errors

```bash
# Make scripts executable
chmod +x *.sh infra/*.sh monitoring/*.sh

# Check Docker permissions
groups $USER | grep docker

# If not in docker group:
sudo usermod -aG docker $USER
newgrp docker
# Or logout and login again
```

#### 2. Docker Not Running

```bash
# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Check status
sudo systemctl status docker

# Test Docker
docker run --rm hello-world
```

#### 3. Port Conflicts

```bash
# Check what's using a port
sudo netstat -tulpn | grep :5432

# Or use ss command
ss -tulpn | grep :5432

# Change port in service .env file
echo "POSTGRES_PORT=5433" >> /data/setulab/infra/postgres/.env
```

#### 4. Disk Space Issues

```bash
# Check available space
df -h

# Clean Docker resources
task clean:all

# Or manually
docker system prune -a -f --volumes
```

#### 5. Memory Issues

```bash
# Check memory usage
free -h

# Check Docker memory usage
docker stats

# Stop unnecessary services
./setulab.sh stop infra <service>
./setulab.sh stop monitoring <service>
```

### Installation Issues

#### Ubuntu/Debian Package Issues

```bash
# Update package lists
sudo apt update

# Fix broken packages
sudo apt --fix-broken install

# Install prerequisites manually
sudo apt install curl wget gnupg lsb-release
```

#### CentOS/RHEL/Fedora Issues

```bash
# Update system
sudo yum update  # or dnf update

# Install prerequisites
sudo yum install curl wget gnupg  # or dnf install
```

#### Network/Firewall Issues

```bash
# Check if ports are blocked
sudo ufw status  # Ubuntu/Debian
sudo firewall-cmd --list-all  # CentOS/RHEL

# Allow Docker ports if needed
sudo ufw allow 2376/tcp  # Docker daemon
sudo ufw allow 5432/tcp  # PostgreSQL
sudo ufw allow 3000/tcp  # Grafana
```

### Getting Help

#### System Information

```bash
# Show detailed system info
./prerequisite.sh --check-only

# Docker information
docker info
docker version

# System logs
journalctl -u docker.service -f
```

#### Log Files

```bash
# Docker logs
docker logs <container_name>

# System logs
tail -f /var/log/syslog  # Ubuntu/Debian
tail -f /var/log/messages  # CentOS/RHEL

# Setulab logs
./setulab.sh status infra
./setulab.sh status monitoring
```

#### Reset Installation

```bash
# Stop all services
task stop:all

# Clean Docker resources
task clean:all

# Remove data (WARNING: This deletes all data!)
sudo rm -rf /data/setulab

# Reinstall prerequisites
./prerequisite.sh --force
```

## 🚀 Next Steps

After successful installation:

1. **Explore Services**: Visit service URLs and explore UIs
2. **Customize Configuration**: Edit `.env` files in `/data/setulab/`
3. **Add More Services**: Use `./setulab.sh setup` for additional services
4. **Monitor Resources**: Use Grafana for observability
5. **Backup Data**: Set up regular backups with `task backup:volumes`

## 📚 Additional Resources

- [Main README](README.md) - Complete documentation
- [Service URLs](README.md#service-urls) - Access information
- [Configuration Guide](README.md#configuration) - Customization options
- [Task Documentation](https://taskfile.dev/) - Task runner guide
- [Docker Documentation](https://docs.docker.com/) - Docker reference

## 🆘 Support

If you encounter issues:

1. Check this troubleshooting guide
2. Run `./prerequisite.sh --check-only` for diagnostics
3. Check service logs with `task logs SERVICE=<name>`
4. Review the main [README](README.md) for detailed information
5. Check Docker documentation for container-specific issues

---

**Happy containerizing! 🐳**