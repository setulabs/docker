#!/bin/bash

# Setulab Automation - Prerequisite Checker and Installer
# Checks and installs Docker, Docker Compose, and Task dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
DOCKER_MIN_VERSION="20.10"
COMPOSE_MIN_VERSION="2.0"
TASK_VERSION="3.37.2"

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

log_header() {
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..60})${NC}"
}

# Function to compare versions
version_ge() {
    local version1="$1"
    local version2="$2"
    # Extract major.minor version numbers only
    local v1_major_minor=$(echo "$version1" | grep -oE '^[0-9]+\.[0-9]+' || echo "$version1")
    local v2_major_minor=$(echo "$version2" | grep -oE '^[0-9]+\.[0-9]+' || echo "$version2")
    # Use sort -V to compare versions, return 0 if v1 >= v2
    printf '%s\n%s\n' "$v2_major_minor" "$v1_major_minor" | sort -V -C
}

# Function to get OS information
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        CODENAME=${VERSION_CODENAME:-}
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"
        VER=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        VER=$(uname -r)
    fi

    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
    esac
}

# Function to ask for user confirmation
ask_confirmation() {
    local message="$1"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    while true; do
        echo -e "${YELLOW}$message $prompt${NC}"
        read -r response

        if [[ -z "$response" ]]; then
            response="$default"
        fi

        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Function to check Docker installation
check_docker() {
    log_info "Checking Docker installation..."

    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_success "Docker is installed: v$docker_version"

        # Check if Docker daemon is running
        if docker info &> /dev/null; then
            log_success "Docker daemon is running"

            # Check Docker permissions
            if docker ps &> /dev/null; then
                log_success "Docker permissions are correct"
            else
                log_warning "Docker requires sudo. Consider adding user to docker group:"
                echo "  sudo usermod -aG docker \$USER"
                echo "  newgrp docker"
            fi
        else
            log_error "Docker daemon is not running. Start it with:"
            echo "  sudo systemctl start docker"
            echo "  sudo systemctl enable docker"
            return 1
        fi

        # Version check - extract major.minor for comparison
        local docker_major_minor=$(echo "$docker_version" | grep -oE '^[0-9]+\.[0-9]+' || echo "$docker_version")
        local min_major_minor=$(echo "$DOCKER_MIN_VERSION" | grep -oE '^[0-9]+\.[0-9]+' || echo "$DOCKER_MIN_VERSION")

        if version_ge "$docker_major_minor" "$min_major_minor"; then
            log_success "Docker version meets requirements (>= $DOCKER_MIN_VERSION)"
            return 0
        else
            log_warning "Docker version $docker_major_minor is below recommended $DOCKER_MIN_VERSION"
            return 2
        fi
    else
        log_error "Docker is not installed"
        return 1
    fi
}

# Function to install Docker
install_docker() {
    log_header "Installing Docker"

    case "$OS" in
        ubuntu|debian)
            log_info "Installing Docker on Ubuntu/Debian..."

            # Update package index
            sudo apt-get update

            # Install prerequisites
            sudo apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release

            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

            # Set up stable repository
            echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            # Install Docker Engine
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        centos|rhel|fedora)
            log_info "Installing Docker on CentOS/RHEL/Fedora..."

            # Install yum-utils
            sudo yum install -y yum-utils

            # Add Docker repository
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

            # Install Docker Engine
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        arch)
            log_info "Installing Docker on Arch Linux..."
            sudo pacman -S docker docker-compose
            ;;

        *)
            log_error "Unsupported OS: $OS"
            log_info "Please install Docker manually from: https://docs.docker.com/engine/install/"
            return 1
            ;;
    esac

    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker

    # Add current user to docker group
    sudo usermod -aG docker "$USER"

    log_success "Docker installed successfully!"
    log_warning "Please log out and log back in for group changes to take effect"
    log_info "Or run: newgrp docker"
}

# Function to check Docker Compose
check_docker_compose() {
    log_info "Checking Docker Compose installation..."

    # Check Docker Compose v2 (plugin)
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short 2>/dev/null || docker compose version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's/v//')
        log_success "Docker Compose (plugin) is installed: v$compose_version"

        # Version check - extract major.minor for comparison
        local compose_major_minor=$(echo "$compose_version" | grep -oE '^[0-9]+\.[0-9]+' || echo "$compose_version")
        local min_major_minor=$(echo "$COMPOSE_MIN_VERSION" | grep -oE '^[0-9]+\.[0-9]+' || echo "$COMPOSE_MIN_VERSION")

        if version_ge "$compose_major_minor" "$min_major_minor"; then
            log_success "Docker Compose version meets requirements (>= $COMPOSE_MIN_VERSION)"
            return 0
        else
            log_warning "Docker Compose version $compose_major_minor is below recommended $COMPOSE_MIN_VERSION"
            return 2
        fi
    fi

    # Check Docker Compose v1 (standalone)
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_success "Docker Compose (standalone) is installed: v$compose_version"
        log_warning "Consider upgrading to Docker Compose v2 (plugin)"
        return 0
    fi

    log_error "Docker Compose is not installed"
    return 1
}

# Function to install Docker Compose
install_docker_compose() {
    log_header "Installing Docker Compose"

    # Docker Compose v2 is usually installed with Docker Engine
    if docker compose version &> /dev/null; then
        log_success "Docker Compose plugin is already available"
        return 0
    fi

    log_info "Installing Docker Compose standalone..."

    # Get latest version if not specified
    local latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    local version="${latest_version#v}"

    # Download and install
    sudo curl -L "https://github.com/docker/compose/releases/download/$latest_version/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose

    sudo chmod +x /usr/local/bin/docker-compose

    # Create symlink for compatibility
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    log_success "Docker Compose installed successfully!"
}

# Function to check Task
check_task() {
    log_info "Checking Task installation..."

    if command -v task &> /dev/null; then
        local task_version=$(task --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_success "Task is installed: v$task_version"

        # Show task information
        echo "  Location: $(which task)"
        return 0
    else
        log_error "Task is not installed"
        return 1
    fi
}

# Function to install Task
install_task() {
    log_header "Installing Task"

    case "$OS" in
        ubuntu|debian)
            log_info "Installing Task on Ubuntu/Debian..."

            # Method 1: Using package manager (if available)
            if curl -s https://api.github.com/repos/go-task/task/releases/latest | grep -q "browser_download_url"; then
                # Download and install from GitHub releases
                local download_url="https://github.com/go-task/task/releases/download/v$TASK_VERSION/task_linux_$ARCH.deb"
                local temp_file="/tmp/task.deb"

                curl -L "$download_url" -o "$temp_file"
                sudo dpkg -i "$temp_file"
                rm -f "$temp_file"
            else
                install_task_binary
            fi
            ;;

        centos|rhel|fedora)
            log_info "Installing Task on CentOS/RHEL/Fedora..."

            local download_url="https://github.com/go-task/task/releases/download/v$TASK_VERSION/task_linux_$ARCH.rpm"
            local temp_file="/tmp/task.rpm"

            curl -L "$download_url" -o "$temp_file"
            sudo rpm -i "$temp_file"
            rm -f "$temp_file"
            ;;

        arch)
            log_info "Installing Task on Arch Linux..."
            sudo pacman -S go-task-bin
            ;;

        *)
            install_task_binary
            ;;
    esac

    log_success "Task installed successfully!"
}

# Function to install Task binary directly
install_task_binary() {
    log_info "Installing Task binary..."

    local download_url="https://github.com/go-task/task/releases/download/v$TASK_VERSION/task_linux_$ARCH.tar.gz"
    local temp_file="/tmp/task.tar.gz"
    local temp_dir="/tmp/task_install"

    # Download
    curl -L "$download_url" -o "$temp_file"

    # Extract
    mkdir -p "$temp_dir"
    tar -xzf "$temp_file" -C "$temp_dir"

    # Install
    sudo mv "$temp_dir/task" /usr/local/bin/task
    sudo chmod +x /usr/local/bin/task

    # Cleanup
    rm -rf "$temp_file" "$temp_dir"
}

# Function to check additional tools
check_additional_tools() {
    log_header "Checking Additional Tools"

    # Check curl
    if command -v curl &> /dev/null; then
        log_success "curl is available"
    else
        log_warning "curl is not installed (recommended for downloading)"
    fi

    # Check git
    if command -v git &> /dev/null; then
        local git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_success "git is available: v$git_version"
    else
        log_warning "git is not installed (recommended for version control)"
    fi

    # Check jq
    if command -v jq &> /dev/null; then
        local jq_version=$(jq --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        log_success "jq is available: v$jq_version"
    else
        log_warning "jq is not installed (useful for JSON processing)"
    fi
}

# Function to show system information
show_system_info() {
    log_header "System Information"

    echo -e "${CYAN}OS:${NC} $OS $VER"
    echo -e "${CYAN}Architecture:${NC} $ARCH"
    echo -e "${CYAN}Kernel:${NC} $(uname -r)"
    echo -e "${CYAN}User:${NC} $(whoami)"
    echo -e "${CYAN}Home:${NC} $HOME"
    echo -e "${CYAN}Shell:${NC} $SHELL"

    # Check available disk space
    local available_space=$(df -h . | awk 'NR==2 {print $4}')
    echo -e "${CYAN}Available Space:${NC} $available_space"

    # Check memory
    local total_memory=$(free -h | awk 'NR==2{printf "%s", $2}')
    echo -e "${CYAN}Total Memory:${NC} $total_memory"
}

# Function to show installation summary
show_summary() {
    log_header "Installation Summary"

    echo -e "${BOLD}Required Dependencies:${NC}"

    # Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo -e "  ✅ Docker: v$docker_version"
    else
        echo -e "  ❌ Docker: Not installed"
    fi

    # Docker Compose
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short 2>/dev/null || echo "installed")
        echo -e "  ✅ Docker Compose: $compose_version"
    elif command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo -e "  ✅ Docker Compose: v$compose_version"
    else
        echo -e "  ❌ Docker Compose: Not installed"
    fi

    # Task
    if command -v task &> /dev/null; then
        local task_version=$(task --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo -e "  ✅ Task: v$task_version"
    else
        echo -e "  ⚠️  Task: Not installed (optional)"
    fi

    echo ""
    echo -e "${BOLD}Next Steps:${NC}"
    echo -e "  1. Run: ${CYAN}./setulab.sh help${NC}"
    echo -e "  2. Setup services: ${CYAN}./setulab.sh setup infra postgres${NC}"
    echo -e "  3. Or use Task: ${CYAN}task postgres:start${NC}"
    echo ""
    echo -e "${BOLD}Service URLs will be available at:${NC}"
    echo -e "  • Grafana: ${CYAN}http://localhost:3000${NC}"
    echo -e "  • Prometheus: ${CYAN}http://localhost:9090${NC}"
    echo -e "  • PgAdmin: ${CYAN}http://localhost:15432${NC}"
}

# Main function
main() {
    clear
    log_header "🚀 Setulab Automation - Prerequisite Checker"

    # Get OS information
    get_os_info
    show_system_info
    echo ""

    # Track what needs to be installed
    local needs_docker=false
    local needs_compose=false
    local needs_task=false

    # Check Docker
    if ! check_docker; then
        needs_docker=true
    fi
    echo ""

    # Check Docker Compose
    if ! check_docker_compose; then
        needs_compose=true
    fi
    echo ""

    # Check Task
    if ! check_task; then
        needs_task=true
    fi
    echo ""

    # Check additional tools
    check_additional_tools
    echo ""

    # Install missing dependencies
    if [[ "$needs_docker" == true ]]; then
        if ask_confirmation "Docker is required. Do you want to install it?"; then
            install_docker
            echo ""
        else
            log_error "Docker is required for Setulab. Exiting."
            exit 1
        fi
    fi

    if [[ "$needs_compose" == true ]]; then
        if ask_confirmation "Docker Compose is required. Do you want to install it?"; then
            install_docker_compose
            echo ""
        else
            log_error "Docker Compose is required for Setulab. Exiting."
            exit 1
        fi
    fi

    if [[ "$needs_task" == true ]]; then
        if ask_confirmation "Task is optional but recommended. Do you want to install it?"; then
            install_task
            echo ""
        else
            log_info "Task installation skipped. You can install it later from: https://taskfile.dev"
            echo ""
        fi
    fi

    # Final summary
    show_summary

    # Final message
    if [[ "$needs_docker" == true ]] || [[ "$needs_compose" == true ]]; then
        log_warning "Some components were installed. You may need to:"
        echo "  1. Log out and log back in (for Docker group permissions)"
        echo "  2. Or run: newgrp docker"
        echo "  3. Restart your terminal session"
        echo ""

        if ask_confirmation "Do you want to test the Docker installation now?"; then
            log_info "Testing Docker installation..."
            if docker run --rm hello-world; then
                log_success "Docker is working correctly!"
            else
                log_error "Docker test failed. Please check the installation."
            fi
        fi
    else
        log_success "All prerequisites are satisfied! 🎉"
        log_info "You can now use Setulab automation."
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Setulab Prerequisite Checker"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --check-only   Only check prerequisites, don't install"
        echo "  --force        Force installation even if already installed"
        echo ""
        echo "This script checks and installs:"
        echo "  • Docker (>= $DOCKER_MIN_VERSION)"
        echo "  • Docker Compose (>= $COMPOSE_MIN_VERSION)"
        echo "  • Task (optional task runner)"
        echo ""
        exit 0
        ;;
    --check-only)
        log_header "🔍 Prerequisite Check Only"
        get_os_info
        show_system_info
        echo ""
        check_docker
        echo ""
        check_docker_compose
        echo ""
        check_task
        echo ""
        check_additional_tools
        echo ""
        show_summary
        exit 0
        ;;
    --force)
        log_warning "Force mode enabled. Will reinstall components."
        ;;
esac

# Run main function
main "$@"
