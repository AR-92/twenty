#!/bin/bash

# Twenty CRM Development Setup Script
# This script sets up and starts the Twenty CRM project in development mode
# It handles environment setup, dependencies, and service orchestration

set -e  # Exit on any error

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
DOCKER_NETWORK="twenty_network"
BACKEND_PORT=3000
FRONTEND_PORT=3001

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed. Please install Node.js (version ^24.5.0) and try again."
        exit 1
    fi
    
    NODE_VERSION=$(node -v | sed 's/v//')
    if [[ $(printf '%s\n' "24.5.0" "$NODE_VERSION" | sort -V | head -n1) != "24.5.0" ]]; then
        log_warn "Node.js version might be too old. Expected: ^24.5.0, Found: $NODE_VERSION"
    fi
    
    # Check Yarn
    if ! command -v yarn &> /dev/null; then
        log_error "Yarn is not installed. Please install Yarn (version ^4.0.2) and try again."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker and start the service."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All prerequisites are met."
}

# Create Docker network if it doesn't exist
setup_docker_network() {
    log_info "Setting up Docker network..."
    
    if ! docker network inspect "$DOCKER_NETWORK" &> /dev/null; then
        docker network create "$DOCKER_NETWORK" > /dev/null
        log_success "Docker network '$DOCKER_NETWORK' created."
    else
        log_info "Docker network '$DOCKER_NETWORK' already exists."
    fi
}

# Start PostgreSQL in Docker
start_postgres() {
    log_info "Starting PostgreSQL in Docker..."
    
    # Check if container already exists and is running
    if [ "$(docker ps -q -f name=twenty_pg)" ]; then
        log_info "PostgreSQL container is already running."
        return
    fi
    
    # Check if container exists but is stopped
    if [ "$(docker ps -aq -f name=twenty_pg)" ]; then
        docker start twenty_pg > /dev/null
        log_info "Started existing PostgreSQL container."
    else
        docker run -d \
            --name twenty_pg \
            --network "$DOCKER_NETWORK" \
            -e POSTGRES_USER=postgres \
            -e POSTGRES_PASSWORD=postgres \
            -e ALLOW_NOSSL=true \
            -v twenty_db_data:/var/lib/postgresql/data \
            -p 5432:5432 \
            postgres:16 > /dev/null
        log_success "PostgreSQL container started."
    fi
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    timeout 60 bash -c 'until docker exec twenty_pg pg_isready > /dev/null 2>&1; do sleep 2; done'
    
    # Create databases
    docker exec twenty_pg psql -U postgres -d postgres \
        -c "CREATE DATABASE IF NOT EXISTS \"default\" WITH OWNER postgres;" \
        -c "CREATE DATABASE IF NOT EXISTS \"test\" WITH OWNER postgres;" > /dev/null 2>&1 || true
    
    log_success "PostgreSQL is ready."
}

# Start Redis in Docker
start_redis() {
    log_info "Starting Redis in Docker..."
    
    # Check if container already exists and is running
    if [ "$(docker ps -q -f name=twenty_redis)" ]; then
        log_info "Redis container is already running."
        return
    fi
    
    # Check if container exists but is stopped
    if [ "$(docker ps -aq -f name=twenty_redis)" ]; then
        docker start twenty_redis > /dev/null
        log_info "Started existing Redis container."
    else
        docker run -d \
            --name twenty_redis \
            --network "$DOCKER_NETWORK" \
            -p 6379:6379 \
            redis/redis-stack-server:latest > /dev/null
        log_success "Redis container started."
    fi
    
    log_success "Redis is ready."
}

# Install project dependencies if needed
install_dependencies() {
    log_info "Checking project dependencies..."
    
    cd "$PROJECT_DIR"
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ] || [ -z "$(ls -A node_modules 2>/dev/null)" ]; then
        log_info "Installing project dependencies..."
        yarn install --network-timeout 100000
        log_success "Dependencies installed."
    else
        log_info "Dependencies already installed."
    fi
}

# Set up environment variables
setup_env_files() {
    log_info "Setting up environment files..."
    
    # Check and create server .env if it doesn't exist
    if [ ! -f "$PROJECT_DIR/packages/twenty-server/.env" ]; then
        if [ -f "$PROJECT_DIR/packages/twenty-server/.env.example" ]; then
            cp "$PROJECT_DIR/packages/twenty-server/.env.example" "$PROJECT_DIR/packages/twenty-server/.env"
            log_success "Created server .env from example file."
        else
            log_warn "Server .env.example not found. You may need to create it manually."
        fi
    else
        log_info "Server .env file already exists."
    fi
    
    # Check and create frontend .env if it doesn't exist
    if [ ! -f "$PROJECT_DIR/packages/twenty-front/.env" ]; then
        if [ -f "$PROJECT_DIR/packages/twenty-front/.env.example" ]; then
            cp "$PROJECT_DIR/packages/twenty-front/.env.example" "$PROJECT_DIR/packages/twenty-front/.env"
            log_success "Created frontend .env from example file."
        else
            log_warn "Frontend .env.example not found. You may need to create it manually."
        fi
    else
        log_info "Frontend .env file already exists."
    fi
    
    # Update essential environment variables
    if [ -f "$PROJECT_DIR/packages/twenty-server/.env" ]; then
        # Ensure database URL is set to local
        if ! grep -q "^PG_DATABASE_URL=" "$PROJECT_DIR/packages/twenty-server/.env"; then
            echo "PG_DATABASE_URL=postgres://postgres:postgres@localhost:5432/default" >> "$PROJECT_DIR/packages/twenty-server/.env"
        else
            sed -i 's|^PG_DATABASE_URL=.*|PG_DATABASE_URL=postgres://postgres:postgres@localhost:5432/default|' "$PROJECT_DIR/packages/twenty-server/.env"
        fi
        
        # Ensure Redis URL is set to local
        if ! grep -q "^REDIS_URL=" "$PROJECT_DIR/packages/twenty-server/.env"; then
            echo "REDIS_URL=redis://localhost:6379" >> "$PROJECT_DIR/packages/twenty-server/.env"
        else
            sed -i 's|^REDIS_URL=.*|REDIS_URL=redis://localhost:6379|' "$PROJECT_DIR/packages/twenty-server/.env"
        fi
        
        # Ensure FRONTEND_URL is set
        if ! grep -q "^FRONTEND_URL=" "$PROJECT_DIR/packages/twenty-server/.env"; then
            echo "FRONTEND_URL=http://localhost:3001" >> "$PROJECT_DIR/packages/twenty-server/.env"
        else
            sed -i 's|^FRONTEND_URL=.*|FRONTEND_URL=http://localhost:3001|' "$PROJECT_DIR/packages/twenty-server/.env"
        fi
        
        # Ensure APP_SECRET is set (for development)
        if ! grep -q "^APP_SECRET=" "$PROJECT_DIR/packages/twenty-server/.env" || [ "$(grep "^APP_SECRET=" "$PROJECT_DIR/packages/twenty-server/.env" | cut -d'=' -f2)" = "replace_me_with_a_random_string" ]; then
            sed -i 's|^APP_SECRET=.*|APP_SECRET=dev_secret_for_development_only|' "$PROJECT_DIR/packages/twenty-server/.env"
        fi
        
        log_success "Updated server environment variables."
    fi
    
    if [ -f "$PROJECT_DIR/packages/twenty-front/.env" ]; then
        # Ensure server URL is set
        if ! grep -q "^REACT_APP_SERVER_BASE_URL=" "$PROJECT_DIR/packages/twenty-front/.env"; then
            echo "REACT_APP_SERVER_BASE_URL=http://localhost:3000" >> "$PROJECT_DIR/packages/twenty-front/.env"
        else
            sed -i 's|^REACT_APP_SERVER_BASE_URL=.*|REACT_APP_SERVER_BASE_URL=http://localhost:3000|' "$PROJECT_DIR/packages/twenty-front/.env"
        fi
        
        log_success "Updated frontend environment variables."
    fi
}

# Initialize the database
init_database() {
    log_info "Initializing database..."
    
    cd "$PROJECT_DIR"
    
    # Run database initialization
    npx nx run twenty-server:database:init:prod
    
    log_success "Database initialized."
}

# Check if a service is running on a port
is_port_in_use() {
    local port=$1
    if command -v lsof &> /dev/null; then
        lsof -Pi :$port -sTCP:LISTEN -t >/dev/null
    elif command -v ss &> /dev/null; then
        ss -tuln | grep -q ":$port "
    elif command -v netstat &> /dev/null; then
        netstat -tuln | grep -q ":$port "
    else
        # Fallback: try to connect to the port
        timeout 1 bash -c "</dev/tcp/localhost/$port" 2>/dev/null
    fi
}

# Wait for a service to be available on a port
wait_for_port() {
    local port=$1
    local timeout=${2:-30}
    local count=0
    
    log_info "Waiting for service on port $port (timeout: ${timeout}s)..."
    
    while [ $count -lt $timeout ]; do
        if is_port_in_use $port; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    return 1
}

# Main function
main() {
    echo
    log_info "==========================================="
    log_info "TWENTY CRM DEVELOPMENT SETUP SCRIPT"
    log_info "==========================================="
    echo
    
    check_prerequisites
    setup_docker_network
    start_postgres
    start_redis
    install_dependencies
    setup_env_files
    init_database
    
    echo
    log_success "==========================================="
    log_success "TWENTY CRM DEVELOPMENT SETUP COMPLETED"
    log_success "==========================================="
    echo
    log_info "Setup completed successfully!"
    log_info "To run the application, use: ./run_dev.sh"
    echo
}

# Run main function
main "$@"