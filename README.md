# 🚀 Setulab Automation

Simple shell-based setup for infrastructure and monitoring using Docker + Compose on Linux.

## 📁 Project Structure

```
/data/setulab/
├── infra/
│   ├── postgres/
│   │   ├── docker-compose.yml
│   │   ├── .env
│   │   └── config/
│   ├── rabbitmq/
│   ├── redis/
│   ├── mongodb/
│   └── ...
├── monitoring/
│   ├── grafana/
│   │   ├── docker-compose.yml
│   │   ├── .env
│   │   └── config/
│   ├── prometheus/
│   ├── dozzle/
│   └── ...
└── scripts/
    ├── setulab.sh
    ├── infra/infra.sh
    └── monitoring/monitoring.sh
```

## 🖥️ Requirements

- **Linux** (Ubuntu, CentOS, Debian, etc.)
- **Docker** (20.10+)
- **Docker Compose** (v2.0+)
- **bash/sh** shell
- **Task** (optional, for Taskfile.yml)

## 🚀 Quick Start

### 1. Check Prerequisites
```bash
# Check and install prerequisites (Docker, Docker Compose, Task)
./prerequisite.sh

# Or just check without installing
./prerequisite.sh --check-only
```

### 2. Make Scripts Executable
```bash
chmod +x *.sh infra/*.sh monitoring/*.sh
```

### 3. Setup Infrastructure Services
```bash
# Setup PostgreSQL and RabbitMQ
./setulab.sh setup infra postgres rabbitmq

# Setup monitoring stack
./setulab.sh setup monitoring grafana prometheus dozzle

# Start services
./setulab.sh start infra postgres rabbitmq
./setulab.sh start monitoring grafana prometheus dozzle
```

### 4. Using Taskfile (Recommended)
```bash
# Install Task runner (if not installed)
# See: https://taskfile.dev/installation/

# Quick start full stack
task full:stack

# Or individual services
task postgres:start
task monitoring:start

# Show all available tasks
task --list
```

## 📦 Available Resources

### Infrastructure Services
- **postgres** - PostgreSQL database
- **rabbitmq** - Message broker with management UI
- **redis** - In-memory data store
- **mongodb** - Document database
- **clickhouse** - Columnar database
- **pg-admin** - PostgreSQL admin interface
- **redis-insight** - Redis GUI
- **supabase-postgres** - Supabase-flavored PostgreSQL

### Monitoring Tools
- **grafana** - Visualization and dashboards
- **prometheus** - Metrics collection and storage
- **dozzle** - Docker container logs viewer
- **loki** - Log aggregation system
- **tempo** - Distributed tracing backend
- **promtail** - Log shipper for Loki
- **alloy** - Grafana Agent alternative
- **hyperdx** - Observability platform

## 🛠️ Usage Examples

### Basic Commands
```bash
# Check prerequisites first
./setulab.sh prereq

# Setup specific services
./setulab.sh setup infra postgres redis
./setulab.sh setup monitoring grafana prometheus

# Start services
./setulab.sh start infra postgres
./setulab.sh start monitoring grafana

# Stop services
./setulab.sh stop infra postgres
./setulab.sh stop monitoring grafana

# Check status
./setulab.sh status infra
./setulab.sh status monitoring postgres

# List available resources
./setulab.sh list infra
./setulab.sh list monitoring
```

### Task Commands
```bash
# Check prerequisites
task prereq
task prereq:check

# Setup and start PostgreSQL with PgAdmin
task postgres:start

# Setup and start monitoring stack
task monitoring:start

# Show service URLs
task docs:urls

# Check service health
task health:check

# View logs
task logs SERVICE=postgres

# Execute commands in containers
task exec SERVICE=postgres CMD='psql -U postgres'

# Backup volumes
task backup:volumes

# Clean unused resources
task clean:all
```

## 🌐 Service URLs

After starting services, access them at:

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin/admin |
| Prometheus | http://localhost:9090 | - |
| Dozzle | http://localhost:8080 | - |
| PgAdmin | http://localhost:15432 | admin@pgadmin.com/password |
| RabbitMQ | http://localhost:15672 | admin/admin |
| Redis Insight | http://localhost:5540 | - |
| Loki | http://localhost:3100 | - |
| Tempo | http://localhost:3200 | - |
| Jaeger | http://localhost:16686 | - |

## ⚙️ Configuration

### Environment Variables
Each service generates a `.env` file with configurable options:

```bash
# Example: PostgreSQL configuration
/data/setulab/infra/postgres/.env
```

```env
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_PORT=5432
```

### Prerequisite Management
The system includes an automated prerequisite checker:

```bash
# Check and install all prerequisites
./prerequisite.sh

# Available options
./prerequisite.sh --help
./prerequisite.sh --check-only    # Check without installing
./prerequisite.sh --force         # Force reinstall

# What it checks and installs:
# - Docker (>= 20.10)
# - Docker Compose (>= 2.0) 
# - Task (optional task runner)
# - Additional tools (curl, git, jq)
```

The script automatically:
- Detects your OS (Ubuntu, Debian, CentOS, RHEL, Fedora, Arch)
- Shows system information
- Checks current versions
- Offers to install missing components
- Configures Docker permissions
- Provides installation guidance

### Custom Configuration
Services support custom configuration files in their `config/` directories:

```bash
# Example: Redis configuration
/data/setulab/infra/redis/config/redis.conf
```

## 🔧 Advanced Usage

### Docker Network
All services use the `oneclick4j` network for inter-service communication:

```bash
# Create network manually
docker network create oneclick4j

# Remove network
docker network rm oneclick4j
```

### Volume Management
Data is persisted using Docker volumes:

```bash
# List volumes
docker volume ls | grep -E "(postgres|redis|grafana)"

# Backup volumes
task backup:volumes

# Clean unused volumes
task clean:volumes
```

### Health Checks
Services include health checks for monitoring:

```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"

# View health check logs
docker inspect <container_name> | jq '.[0].State.Health'
```

## 🔍 Troubleshooting

### Prerequisites Issues

**Missing Dependencies**
```bash
# Run prerequisite checker
./prerequisite.sh

# Or with Task
task prereq
```

**Docker Permission Issues**
```bash
# Add user to docker group (prerequisite.sh does this automatically)
sudo usermod -aG docker $USER
newgrp docker

# Or restart your session
```

**Docker Not Running**
```bash
# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

### Common Issues

**Port Conflicts**
```bash
# Check what's using a port
sudo netstat -tulpn | grep :5432

# Change port in .env file
echo "POSTGRES_PORT=5433" >> /data/setulab/infra/postgres/.env
```

**Permission Issues**
```bash
# Fix script permissions
chmod +x *.sh infra/*.sh monitoring/*.sh

# Fix data directory permissions
sudo chown -R $USER:$USER /data/setulab
```

**Docker Issues**
```bash
# Restart Docker service
sudo systemctl restart docker

# Check Docker status
sudo systemctl status docker

# View Docker logs
sudo journalctl -u docker.service
```

### Logs and Debugging
```bash
# View service logs
docker logs -f <container_name>

# View all logs with Dozzle
./setulab.sh start monitoring dozzle
# Open http://localhost:8080

# Debug compose files
docker-compose -f /data/setulab/infra/postgres/docker-compose.yml config
```

## 🔒 Security Considerations

### Default Credentials
**⚠️ Change default passwords in production!**

```bash
# Update .env files with secure passwords
nano /data/setulab/infra/postgres/.env
nano /data/setulab/monitoring/grafana/.env
```

### Network Security
```bash
# Bind services to localhost only
# Edit docker-compose.yml port mappings:
# ports:
#   - "127.0.0.1:5432:5432"  # Only localhost access
```

### Image Security
```bash
# Scan images for vulnerabilities
task security:scan

# Update to latest images
task update:images
```

## 📊 Monitoring Setup

### Complete Observability Stack
```bash
# Setup full monitoring stack
task setup:monitoring -- grafana prometheus loki tempo dozzle promtail

# Start monitoring
task start:monitoring -- grafana prometheus loki tempo dozzle promtail
```

### Grafana Dashboards
Pre-configured dashboards for:
- System metrics (Node Exporter)
- Container metrics (cAdvisor)
- Application logs (Loki)
- Distributed tracing (Tempo)

### Prometheus Targets
Automatic discovery of:
- Docker containers
- Host system metrics
- Custom application metrics

## 🔄 Backup and Recovery

### Automated Backups
```bash
# Create backup
task backup:volumes

# Backup location
ls /data/setulab/backups/
```

### Manual Backup
```bash
# Backup specific service
docker run --rm -v postgres_data:/source -v $(pwd)/backup:/backup alpine \
  tar czf /backup/postgres_$(date +%Y%m%d).tar.gz -C /source .
```

### Recovery
```bash
# Stop service
./setulab.sh stop infra postgres

# Restore volume
docker run --rm -v postgres_data:/target -v $(pwd)/backup:/backup alpine \
  tar xzf /backup/postgres_20240101.tar.gz -C /target

# Start service
./setulab.sh start infra postgres
```

## 🚀 Development Tips

### Adding New Services
1. Add service name to arrays in `setulab.sh`
2. Add compose template in `infra.sh` or `monitoring.sh`
3. Add environment variables template
4. Add configuration files if needed
5. Test setup and start commands

### Custom Compose Files
```bash
# Use existing compose file as template
cp /data/setulab/infra/postgres/docker-compose.yml my-custom-service.yml

# Edit as needed
nano my-custom-service.yml

# Start manually
docker-compose -f my-custom-service.yml up -d
```

### Integration with CI/CD
```yaml
# Example GitHub Actions
- name: Setup Infrastructure
  run: |
    ./docker/setulab.sh setup infra postgres redis
    ./docker/setulab.sh start infra postgres redis
```

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Task Documentation](https://taskfile.dev/)

## 🔧 Prerequisite Details

The `prerequisite.sh` script supports multiple Linux distributions:

**Supported Operating Systems:**
- Ubuntu/Debian (APT packages)
- CentOS/RHEL/Fedora (YUM/DNF packages)
- Arch Linux (Pacman packages)
- Generic Linux (Binary downloads)

**Installation Methods:**
- Docker: Official repositories with GPG verification
- Docker Compose: Plugin (preferred) or standalone binary
- Task: Package manager or GitHub releases
- Automatic service startup and user permissions

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add new service templates
4. Update documentation
5. Test thoroughly
6. Submit pull request

## 📄 License

This project is licensed under the MIT License.

---

**Happy containerizing! 🐳**