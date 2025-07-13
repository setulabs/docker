#!/bin/bash

# Setulab Automation - Main Setup Script
# Simple shell-based setup for infra and monitoring using Docker + Compose on Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="/data/setulab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Available resources
INFRA_RESOURCES=(
    "clickhouse"
    "mongodb"
    "pg-admin"
    "postgres"
    "rabbitmq"
    "redis"
    "redis-insight"
    "supabase-postgres"
)

MONITORING_RESOURCES=(
    "grafana"
    "prometheus"
    "dozzle"
    "hyperdx"
    "loki"
    "tempo"
    "promtail"
    "alloy"
)

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
🚀 Setulab Automation

Usage: ./setulab.sh <command> [options]

Commands:
    prereq                                      Check and install prerequisites
    setup <type> <resource1> <resource2> ...    Setup specified resources
    start <type> <resource1> <resource2> ...    Start specified resources
    stop <type> <resource1> <resource2> ...     Stop specified resources
    status <type> [resource]                    Show status of resources
    list <type>                                 List available resources
    help                                        Show this help message

Types:
    infra       Infrastructure services
    monitoring  Monitoring tools

Examples:
    ./setulab.sh prereq                         # Check prerequisites first
    ./setulab.sh setup infra postgres rabbitmq
    ./setulab.sh setup monitoring grafana dozzle
    ./setulab.sh start infra postgres
    ./setulab.sh stop monitoring grafana
    ./setulab.sh status infra
    ./setulab.sh list infra

Available Infrastructure Resources:
    ${INFRA_RESOURCES[*]}

Available Monitoring Resources:
    ${MONITORING_RESOURCES[*]}

Prerequisites:
    Run './setulab.sh prereq' to check and install Docker, Docker Compose, and Task

EOF
}

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed."
        log_info "Run './setulab.sh prereq' to check and install prerequisites"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed."
        log_info "Run './setulab.sh prereq' to check and install prerequisites"
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running."
        log_info "Start Docker with: sudo systemctl start docker"
        exit 1
    fi

    log_success "Dependencies check passed"
}

create_base_structure() {
    log_info "Creating base directory structure..."

    mkdir -p "$BASE_DIR"/{infra,monitoring}

    # Create docker network if it doesn't exist
    if ! docker network ls | grep -q "oneclick4j"; then
        log_info "Creating Docker network 'oneclick4j'..."
        docker network create oneclick4j
        log_success "Docker network 'oneclick4j' created"
    fi

    log_success "Base structure created"
}

validate_resources() {
    local type=$1
    shift
    local resources=("$@")
    local valid_resources

    case $type in
        "infra")
            valid_resources=("${INFRA_RESOURCES[@]}")
            ;;
        "monitoring")
            valid_resources=("${MONITORING_RESOURCES[@]}")
            ;;
        *)
            log_error "Invalid type: $type. Use 'infra' or 'monitoring'"
            exit 1
            ;;
    esac

    for resource in "${resources[@]}"; do
        if [[ ! " ${valid_resources[*]} " =~ " ${resource} " ]]; then
            log_error "Invalid $type resource: $resource"
            log_info "Available $type resources: ${valid_resources[*]}"
            exit 1
        fi
    done
}

setup_resources() {
    local type=$1
    shift
    local resources=("$@")

    log_info "Setting up $type resources: ${resources[*]}"

    validate_resources "$type" "${resources[@]}"
    create_base_structure

    # Delegate to sub-scripts
    case $type in
        "infra")
            "$SCRIPT_DIR/infra/infra.sh" setup "${resources[@]}"
            ;;
        "monitoring")
            "$SCRIPT_DIR/monitoring/monitoring.sh" setup "${resources[@]}"
            ;;
    esac

    log_success "Setup completed for $type resources: ${resources[*]}"
}

start_resources() {
    local type=$1
    shift
    local resources=("$@")

    log_info "Starting $type resources: ${resources[*]}"

    validate_resources "$type" "${resources[@]}"

    case $type in
        "infra")
            "$SCRIPT_DIR/infra/infra.sh" start "${resources[@]}"
            ;;
        "monitoring")
            "$SCRIPT_DIR/monitoring/monitoring.sh" start "${resources[@]}"
            ;;
    esac

    log_success "Started $type resources: ${resources[*]}"
}

stop_resources() {
    local type=$1
    shift
    local resources=("$@")

    log_info "Stopping $type resources: ${resources[*]}"

    validate_resources "$type" "${resources[@]}"

    case $type in
        "infra")
            "$SCRIPT_DIR/infra/infra.sh" stop "${resources[@]}"
            ;;
        "monitoring")
            "$SCRIPT_DIR/monitoring/monitoring.sh" stop "${resources[@]}"
            ;;
    esac

    log_success "Stopped $type resources: ${resources[*]}"
}

show_status() {
    local type=$1
    local resource=$2

    log_info "Showing status for $type"

    case $type in
        "infra")
            "$SCRIPT_DIR/infra/infra.sh" status "$resource"
            ;;
        "monitoring")
            "$SCRIPT_DIR/monitoring/monitoring.sh" status "$resource"
            ;;
    esac
}

list_resources() {
    local type=$1

    case $type in
        "infra")
            log_info "Available infrastructure resources:"
            printf '%s\n' "${INFRA_RESOURCES[@]}"
            ;;
        "monitoring")
            log_info "Available monitoring resources:"
            printf '%s\n' "${MONITORING_RESOURCES[@]}"
            ;;
        *)
            log_error "Invalid type: $type. Use 'infra' or 'monitoring'"
            exit 1
            ;;
    esac
}

run_prerequisite_check() {
    local prereq_script="$SCRIPT_DIR/prerequisite.sh"

    if [[ -f "$prereq_script" ]]; then
        log_info "Running prerequisite checker..."
        bash "$prereq_script" "$@"
    else
        log_error "Prerequisite script not found: $prereq_script"
        log_info "Please ensure prerequisite.sh is in the same directory as setulab.sh"
        exit 1
    fi
}

# Main script logic
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command=$1
    shift

    case $command in
        "prereq"|"prerequisite"|"prerequisites")
            run_prerequisite_check "$@"
            ;;
        "setup")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 setup <type> <resource1> [resource2] ..."
                exit 1
            fi
            check_dependencies
            setup_resources "$@"
            ;;
        "start")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 start <type> <resource1> [resource2] ..."
                exit 1
            fi
            check_dependencies
            start_resources "$@"
            ;;
        "stop")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 stop <type> <resource1> [resource2] ..."
                exit 1
            fi
            stop_resources "$@"
            ;;
        "status")
            if [[ $# -lt 1 ]]; then
                log_error "Usage: $0 status <type> [resource]"
                exit 1
            fi
            check_dependencies
            show_status "$@"
            ;;
        "list")
            if [[ $# -lt 1 ]]; then
                log_error "Usage: $0 list <type>"
                exit 1
            fi
            list_resources "$1"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            log_info "Run './setulab.sh prereq' to check prerequisites first"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
