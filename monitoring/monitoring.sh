#!/bin/bash

# Setulab Automation - Monitoring Setup Script
# Manages monitoring services using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="/data/setulab"
MONITORING_DIR="$BASE_DIR/monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions
log_info() {
    echo -e "${BLUE}[MONITORING]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[MONITORING]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[MONITORING]${NC} $1"
}

log_error() {
    echo -e "${RED}[MONITORING]${NC} $1"
}

# Create resource directory structure
create_resource_dir() {
    local resource=$1
    local resource_dir="$MONITORING_DIR/$resource"

    log_info "Creating directory structure for $resource..."

    mkdir -p "$resource_dir"/{config,volumes,data}

    log_success "Directory structure created for $resource"
}

# Generate docker-compose.yml for each resource
generate_compose_file() {
    local resource=$1
    local resource_dir="$MONITORING_DIR/$resource"

    log_info "Generating docker-compose.yml for $resource..."

    case $resource in
        "grafana")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER:-admin}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:-admin}
      GF_INSTALL_PLUGINS: ${GRAFANA_PLUGINS:-grafana-clock-panel,grafana-simple-json-datasource}
    ports:
      - "${GRAFANA_PORT:-3000}:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config:/etc/grafana/provisioning
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
    networks:
      - oneclick4j

volumes:
  grafana_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "prometheus")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    ports:
      - "${PROMETHEUS_PORT:-9090}:9090"
    volumes:
      - prometheus_data:/prometheus
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./config/alert.rules:/etc/prometheus/alert.rules
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9090/"]
      interval: 30s
      timeout: 10s
      retries: 5
    networks:
      - oneclick4j

volumes:
  prometheus_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "dozzle")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "${DOZZLE_PORT:-8080}:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      DOZZLE_LEVEL: ${DOZZLE_LEVEL:-info}
      DOZZLE_TAILSIZE: ${DOZZLE_TAILSIZE:-300}
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 5
    networks:
      - oneclick4j

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "hyperdx")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  hyperdx:
    image: hyperdx/hyperdx:latest
    container_name: hyperdx
    restart: unless-stopped
    ports:
      - "${HYPERDX_PORT:-8000}:8000"
    environment:
      HYPERDX_API_KEY: ${HYPERDX_API_KEY:-}
      HYPERDX_SERVICE_NAME: ${HYPERDX_SERVICE_NAME:-setulab}
    volumes:
      - hyperdx_data:/app/data
    networks:
      - oneclick4j

volumes:
  hyperdx_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "loki")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    ports:
      - "${LOKI_PORT:-3100}:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - loki_data:/loki
      - ./config/loki-config.yaml:/etc/loki/local-config.yaml
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3100/ready"]
      interval: 30s
      timeout: 10s
      retries: 5
    networks:
      - oneclick4j

volumes:
  loki_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "tempo")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  tempo:
    image: grafana/tempo:latest
    container_name: tempo
    restart: unless-stopped
    command: [ "-config.file=/etc/tempo.yaml" ]
    volumes:
      - tempo_data:/tmp/tempo
      - ./config/tempo.yaml:/etc/tempo.yaml
    ports:
      - "${TEMPO_PORT:-3200}:3200"
      - "${TEMPO_OTLP_PORT:-4317}:4317"
      - "${TEMPO_OTLP_HTTP_PORT:-4318}:4318"
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3200/ready"]
      interval: 30s
      timeout: 10s
      retries: 5
    networks:
      - oneclick4j

volumes:
  tempo_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "promtail")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    command: -config.file=/etc/promtail/config.yml
    volumes:
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./config/promtail-config.yml:/etc/promtail/config.yml
    ports:
      - "${PROMTAIL_PORT:-9080}:9080"
    networks:
      - oneclick4j

networks:
  oneclick4j:
    external: true
EOF
            ;;

        "alloy")
            cat > "$resource_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  alloy:
    image: grafana/alloy:latest
    container_name: alloy
    restart: unless-stopped
    command:
      - run
      - /etc/alloy/config.alloy
      - --server.http.listen-addr=0.0.0.0:12345
    volumes:
      - alloy_data:/var/lib/alloy/data
      - ./config/config.alloy:/etc/alloy/config.alloy
    ports:
      - "${ALLOY_PORT:-12345}:12345"
    networks:
      - oneclick4j

volumes:
  alloy_data:

networks:
  oneclick4j:
    external: true
EOF
            ;;

        *)
            log_error "Unknown monitoring resource: $resource"
            exit 1
            ;;
    esac

    log_success "Generated docker-compose.yml for $resource"
}

# Generate .env file template
generate_env_file() {
    local resource=$1
    local resource_dir="$MONITORING_DIR/$resource"

    log_info "Generating .env template for $resource..."

    case $resource in
        "grafana")
            cat > "$resource_dir/.env" << 'EOF'
# Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
GRAFANA_PORT=3000
GRAFANA_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
EOF
            ;;

        "prometheus")
            cat > "$resource_dir/.env" << 'EOF'
# Prometheus Configuration
PROMETHEUS_PORT=9090
EOF
            ;;

        "dozzle")
            cat > "$resource_dir/.env" << 'EOF'
# Dozzle Configuration
DOZZLE_PORT=8080
DOZZLE_LEVEL=info
DOZZLE_TAILSIZE=300
EOF
            ;;

        "hyperdx")
            cat > "$resource_dir/.env" << 'EOF'
# HyperDX Configuration
HYPERDX_PORT=8000
HYPERDX_API_KEY=
HYPERDX_SERVICE_NAME=setulab
EOF
            ;;

        "loki")
            cat > "$resource_dir/.env" << 'EOF'
# Loki Configuration
LOKI_PORT=3100
EOF
            ;;

        "tempo")
            cat > "$resource_dir/.env" << 'EOF'
# Tempo Configuration
TEMPO_PORT=3200
TEMPO_OTLP_PORT=4317
TEMPO_OTLP_HTTP_PORT=4318
EOF
            ;;

        "promtail")
            cat > "$resource_dir/.env" << 'EOF'
# Promtail Configuration
PROMTAIL_PORT=9080
EOF
            ;;

        "alloy")
            cat > "$resource_dir/.env" << 'EOF'
# Alloy Configuration
ALLOY_PORT=12345
EOF
            ;;
    esac

    log_success "Generated .env template for $resource"
}

# Generate basic configuration files
generate_config_files() {
    local resource=$1
    local resource_dir="$MONITORING_DIR/$resource"

    log_info "Generating configuration files for $resource..."

    case $resource in
        "grafana")
            mkdir -p "$resource_dir/config"/{dashboards,datasources}

            cat > "$resource_dir/config/datasources/datasource.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF
            ;;

        "prometheus")
            cat > "$resource_dir/config/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert.rules"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'docker'
    static_configs:
      - targets: ['host.docker.internal:9323']

alerting:
  alertmanagers:
    - static_configs:
        - targets: []
EOF

            cat > "$resource_dir/config/alert.rules" << 'EOF'
groups:
  - name: example
    rules:
      - alert: HighErrorRate
        expr: job:request_latency_seconds:mean5m{job="myjob"} > 0.5
        for: 10m
        labels:
          severity: page
        annotations:
          summary: High request latency
EOF
            ;;

        "loki")
            cat > "$resource_dir/config/loki-config.yaml" << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

ingester:
  wal:
    enabled: true
    dir: /loki/wal
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 1h
  max_chunk_age: 1h
  chunk_target_size: 1048576
  chunk_retain_period: 30s
  max_transfer_retries: 0

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

compactor:
  working_directory: /loki/boltdb-shipper-compactor
  shared_store: filesystem

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s

ruler:
  storage:
    type: local
    local:
      directory: /loki/rules
  rule_path: /loki/rules-temp
  alertmanager_url: http://localhost:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
EOF
            ;;

        "tempo")
            cat > "$resource_dir/config/tempo.yaml" << 'EOF'
server:
  http_listen_port: 3200

distributor:
  receivers:
    jaeger:
      protocols:
        thrift_http:
          endpoint: 0.0.0.0:14268
        grpc:
          endpoint: 0.0.0.0:14250
        thrift_binary:
          endpoint: 0.0.0.0:6832
        thrift_compact:
          endpoint: 0.0.0.0:6831
    zipkin:
      endpoint: 0.0.0.0:9411
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318
        grpc:
          endpoint: 0.0.0.0:4317
    opencensus:
      endpoint: 0.0.0.0:55678

ingester:
  trace_idle_period: 10s
  max_block_bytes: 1_000_000
  max_block_duration: 5m

compactor:
  compaction:
    compaction_window: 1h
    max_block_bytes: 100_000_000
    block_retention: 1h
    compacted_block_retention: 10m

storage:
  trace:
    backend: local
    block:
      bloom_filter_false_positive: .05
      index_downsample_bytes: 1000
      encoding: zstd
    wal:
      path: /tmp/tempo/wal
      encoding: snappy
    local:
      path: /tmp/tempo/blocks
    pool:
      max_workers: 100
      queue_depth: 10000
EOF
            ;;

        "promtail")
            cat > "$resource_dir/config/promtail-config.yml" << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log

    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[^|]*))\|
          source: tag
      - timestamp:
          format: RFC3339Nano
          source: time
      - labels:
          stream:
          container_name:
      - output:
          source: output
EOF
            ;;

        "alloy")
            cat > "$resource_dir/config/config.alloy" << 'EOF'
logging {
  level  = "info"
  format = "logfmt"
}

prometheus.scrape "default" {
  targets = [{
    __address__ = "localhost:9090",
  }]
  forward_to = [prometheus.remote_write.default.receiver]
}

prometheus.remote_write "default" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}
EOF
            ;;
    esac

    log_success "Generated configuration files for $resource"
}

# Setup a single resource
setup_resource() {
    local resource=$1

    log_info "Setting up monitoring resource: $resource"

    create_resource_dir "$resource"
    generate_compose_file "$resource"
    generate_env_file "$resource"
    generate_config_files "$resource"

    log_success "Successfully set up monitoring resource: $resource"
}

# Start resources
start_resources() {
    local resources=("$@")

    for resource in "${resources[@]}"; do
        local resource_dir="$MONITORING_DIR/$resource"

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
        local resource_dir="$MONITORING_DIR/$resource"

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
        local resource_dir="$MONITORING_DIR/$resource"

        if [[ ! -d "$resource_dir" ]]; then
            log_error "Resource $resource is not set up."
            return 1
        fi

        log_info "Status for $resource:"
        cd "$resource_dir"
        docker-compose ps
    else
        log_info "Monitoring services status:"

        for dir in "$MONITORING_DIR"/*; do
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
