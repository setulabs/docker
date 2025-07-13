#!/bin/bash

# Setulab Automation - Infrastructure Setup Script
# Manages infrastructure services using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="/data/setulab"
INFRA_DIR="$BASE_DIR/infra"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFRA]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[INFRA]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[INFRA]${NC} $1"
}

log_error() {
    echo -e "${RED}[INFRA]${NC} $1"
}

# Create resource directory structure
create_resource_dir() {
    local resource=$1
    local resource_dir="$INFRA_DIR/$resource"

    log_info "Creating directory structure for $resource..."

    mkdir -p "$resource_dir"/{config,volumes,data}

    log_success "Directory structure created for $resource"
}

# Generate docker-compose.yml for each resource
generate_compose_file() {
    local resource=$1
    local resource_dir="$INFRA_DIR/$resource"

    log_info "Generating docker-compose.yml for $resource..."

    case $resource in
        "postgres")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-postgres}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./config:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - oneclick4j

volumes:
  postgres_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "rabbitmq")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  rabbitmq:
    image: rabbitmq:3-management
    container_name: rabbitmq
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER:-admin}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:-admin}
    ports:
      - "${RABBITMQ_PORT:-5672}:5672"
      - "${RABBITMQ_MGMT_PORT:-15672}:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
      - ./config:/etc/rabbitmq
    healthcheck:
      test: rabbitmq-diagnostics check_port_connectivity
      interval: 30s
      timeout: 30s
      retries: 10
    networks:
      - oneclick4j

volumes:
  rabbitmq_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "redis")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    ports:
      - "${REDIS_PORT:-6379}:6379"
    volumes:
      - redis_data:/data
      - ./config/redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5
    networks:
      - oneclick4j

volumes:
  redis_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "mongodb")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  mongodb:
    image: mongo:7
    container_name: mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USERNAME:-admin}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD:-admin}
      MONGO_INITDB_DATABASE: ${MONGO_DATABASE:-setulab}
    ports:
      - "${MONGO_PORT:-27017}:27017"
    volumes:
      - mongodb_data:/data/db
      - ./config:/docker-entrypoint-initdb.d
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 10s
      retries: 5
    networks:
      - oneclick4j

volumes:
  mongodb_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "clickhouse")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  clickhouse:
    image: clickhouse/clickhouse-server:latest
    container_name: clickhouse
    restart: unless-stopped
    ports:
      - "${CLICKHOUSE_HTTP_PORT:-8123}:8123"
      - "${CLICKHOUSE_NATIVE_PORT:-9000}:9000"
    volumes:
      - clickhouse_data:/var/lib/clickhouse
      - ./config:/etc/clickhouse-server/config.d
    ulimits:
      nofile:
        soft: 262144
        hard: 262144
    healthcheck:
      test: ["CMD", "clickhouse-client", "--query", "SELECT 1"]
      interval: 30s
      timeout: 10s
      retries: 5
    networks:
      - oneclick4j

volumes:
  clickhouse_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "pg-admin")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL:-admin@pgadmin.com}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD:-password}
      PGADMIN_LISTEN_PORT: 80
    ports:
      - "${PGADMIN_PORT:-15432}:80"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
      - ./config:/pgadmin4/config
    networks:
      - oneclick4j

volumes:
  pgadmin_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "redis-insight")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  redis-insight:
    image: redis/redisinsight:latest
    container_name: redis-insight
    restart: unless-stopped
    ports:
      - "${REDIS_INSIGHT_PORT:-5540}:5540"
    volumes:
      - redis_insight_data:/data
    networks:
      - oneclick4j

volumes:
  redis_insight_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "supabase-postgres")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  supabase-postgres:
    image: supabase/postgres:15.1.0.147
    container_name: supabase-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-postgres}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
    ports:
      - "${POSTGRES_PORT:-5433}:5432"
    volumes:
      - supabase_postgres_data:/var/lib/postgresql/data
      - ./config:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - oneclick4j

volumes:
  supabase_postgres_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        *)
            log_error "Unknown infrastructure resource: $resource"
            exit 1
            ;;
    esac

    log_success "Generated docker-compose.yml for $resource"
}

# Generate .env file template
generate_env_file() {
    local resource=$1
    local resource_dir="$INFRA_DIR/$resource"

    log_info "Generating .env template for $resource..."

    case $resource in
        "postgres")
            cat > "$resource_dir/.env" << 'EOF'
# PostgreSQL Configuration
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_PORT=5432
EOF
            ;;

        "rabbitmq")
            cat > "$resource_dir/.env" << 'EOF'
# RabbitMQ Configuration
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=admin
RABBITMQ_PORT=5672
RABBITMQ_MGMT_PORT=15672
EOF
            ;;

        "redis")
            cat > "$resource_dir/.env" << 'EOF'
# Redis Configuration
REDIS_PORT=6379
EOF
            ;;

        "mongodb")
            cat > "$resource_dir/.env" << 'EOF'
# MongoDB Configuration
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=admin
MONGO_DATABASE=setulab
MONGO_PORT=27017
EOF
            ;;

        "clickhouse")
            cat > "$resource_dir/.env" << 'EOF'
# ClickHouse Configuration
CLICKHOUSE_HTTP_PORT=8123
CLICKHOUSE_NATIVE_PORT=9000
EOF
            ;;

        "pg-admin")
            cat > "$resource_dir/.env" << 'EOF'
# PgAdmin Configuration
PGADMIN_EMAIL=admin@pgadmin.com
PGADMIN_PASSWORD=password
PGADMIN_PORT=15432
EOF
            ;;

        "redis-insight")
            cat > "$resource_dir/.env" << 'EOF'
# Redis Insight Configuration
REDIS_INSIGHT_PORT=5540
EOF
            ;;

        "supabase-postgres")
            cat > "$resource_dir/.env" << 'EOF'
# Supabase PostgreSQL Configuration
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_PORT=5433
EOF
            ;;
    esac

    log_success "Generated .env template for $resource"
}

# Generate basic configuration files
generate_config_files() {
    local resource=$1
    local resource_dir="$INFRA_DIR/$resource"

    log_info "Generating configuration files for $resource..."

    case $resource in
        "redis")
            cat > "$resource_dir/config/redis.conf" << 'EOF'
# Redis Configuration
bind 0.0.0.0
port 6379
protected-mode no
save 900 1
save 300 10
save 60 10000
rdbcompression yes
dbfilename dump.rdb
dir /data
maxmemory 256mb
maxmemory-policy allkeys-lru
EOF
            ;;

        "postgres"|"supabase-postgres")
            cat > "$resource_dir/config/init.sql" << 'EOF'
-- Initialize database
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create sample schema
CREATE SCHEMA IF NOT EXISTS setulab;
EOF
            ;;

        "mongodb")
            cat > "$resource_dir/config/init.js" << 'EOF'
// Initialize MongoDB
db = db.getSiblingDB('setulab');

// Create sample collection
db.createCollection('users');

// Create sample document
db.users.insertOne({
    name: 'admin',
    email: 'admin@setulab.com',
    created_at: new Date()
});
EOF
            ;;
    esac

    log_success "Generated configuration files for $resource"
}

# Setup a single resource
setup_resource() {
    local resource=$1

    log_info "Setting up infrastructure resource: $resource"

    create_resource_dir "$resource"
    generate_compose_file "$resource"
    generate_env_file "$resource"
    generate_config_files "$resource"

    log_success "Successfully set up infrastructure resource: $resource"
}

# Start resources
start_resources() {
    local resources=("$@")

    for resource in "${resources[@]}"; do
        local resource_dir="$INFRA_DIR/$resource"

        if [[ ! -d "$resource_dir" ]]; then
            log_error "Resource $resource is not set up. Run setup first."
            continue
        fi

        log_info "Starting $resource..."

        cd "$resource_dir"
        docker-compose up -d

        log_success "Started $resource"
    done
}

# Stop resources
stop_resources() {
    local resources=("$@")

    for resource in "${resources[@]}"; do
        local resource_dir="$INFRA_DIR/$resource"

        if [[ ! -d "$resource_dir" ]]; then
            log_warning "Resource $resource is not set up."
            continue
        fi

        log_info "Stopping $resource..."

        cd "$resource_dir"
        docker-compose down

        log_success "Stopped $resource"
    done
}

# Show status
show_status() {
    local resource=$1

    if [[ -n "$resource" ]]; then
        local resource_dir="$INFRA_DIR/$resource"

        if [[ ! -d "$resource_dir" ]]; then
            log_error "Resource $resource is not set up."
            return 1
        fi

        log_info "Status for $resource:"
        cd "$resource_dir"
        docker-compose ps
    else
        log_info "Infrastructure services status:"

        for dir in "$INFRA_DIR"/*; do
            if [[ -d "$dir" ]]; then
                local resource_name=$(basename "$dir")
                echo -e "\n${BLUE}=== $resource_name ===${NC}"
                cd "$dir"
                docker-compose ps
            fi
        done
    fi
}

# Main script logic
main() {
    local command=$1
    shift

    case $command in
        "setup")
            local resources=("$@")
            for resource in "${resources[@]}"; do
                setup_resource "$resource"
            done
            ;;
        "start")
            start_resources "$@"
            ;;
        "stop")
            stop_resources "$@"
            ;;
        "status")
            show_status "$1"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Usage: $0 {setup|start|stop|status} [resources...]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
