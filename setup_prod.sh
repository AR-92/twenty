#!/bin/bash

# Twenty CRM Production Setup Script
# This script sets up and starts the Twenty CRM project in production mode
# It handles environment setup, dependencies, and service orchestration for production use

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
    
    # Check if docker-compose is available (for production setup)
    if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
        log_warn "Docker Compose is not available. Some advanced features may not work."
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

# Start PostgreSQL in Docker with production settings
start_postgres() {
    log_info "Starting PostgreSQL in Docker with production settings..."
    
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
        log_info "Starting new PostgreSQL container with optimized settings..."
        docker run -d \
            --name twenty_pg \
            --network "$DOCKER_NETWORK" \
            -e POSTGRES_USER=postgres \
            -e POSTGRES_PASSWORD=postgres \
            -e ALLOW_NOSSL=true \
            -v twenty_db_data:/var/lib/postgresql/data \
            -p 5432:5432 \
            -e POSTGRES_DB=default \
            -e PGDATA=/var/lib/postgresql/data/pgdata \
            --restart unless-stopped \
            postgres:16 \
            -c max_connections=200 \
            -c shared_buffers=256MB \
            -c effective_cache_size=1GB \
            -c maintenance_work_mem=64MB \
            -c checkpoint_completion_target=0.9 \
            -c wal_buffers=16MB \
            -c default_statistics_target=100 \
            -c random_page_cost=1.1 \
            -c effective_io_concurrency=200 > /dev/null
        log_success "PostgreSQL container started with production settings."
    fi
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    timeout 60 bash -c 'until docker exec twenty_pg pg_isready > /dev/null 2>&1; do sleep 2; done'
    
    log_success "PostgreSQL is ready."
}

# Start Redis in Docker with production settings
start_redis() {
    log_info "Starting Redis in Docker with production settings..."
    
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
        # Create Redis config
        cat > /tmp/redis.conf << 'EOF'
maxmemory 256mb
maxmemory-policy allkeys-lru
appendonly yes
save 900 1
save 300 10
save 60 10000
tcp-keepalive 300
timeout 300
bind 0.0.0.0
EOF
        docker run -d \
            --name twenty_redis \
            --network "$DOCKER_NETWORK" \
            -p 6379:6379 \
            -v /tmp/redis.conf:/usr/local/etc/redis/redis.conf \
            --restart unless-stopped \
            redis/redis-stack-server:latest \
            redis-server /usr/local/etc/redis/redis.conf > /dev/null
        log_success "Redis container started with production settings."
    fi
    
    log_success "Redis is ready."
}

# Install project dependencies
install_dependencies() {
    log_info "Installing project dependencies..."
    
    cd "$PROJECT_DIR"
    
    # Clean install to ensure consistent state
    if [ -d "node_modules" ]; then
        rm -rf node_modules
    fi
    
    # Install with frozen lockfile for production
    yarn install --immutable --network-timeout 100000
    log_success "Dependencies installed."
}

# Set up production environment variables
setup_env_files() {
    log_info "Setting up production environment files..."
    
    # Check and create server .env if it doesn't exist
    if [ ! -f "$PROJECT_DIR/packages/twenty-server/.env" ]; then
        if [ -f "$PROJECT_DIR/packages/twenty-server/.env.example" ]; then
            cp "$PROJECT_DIR/packages/twenty-server/.env.example" "$PROJECT_DIR/packages/twenty-server/.env"
            log_success "Created server .env from example file."
        else
            log_error "Server .env.example not found. You need to create it manually."
            exit 1
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
            log_error "Frontend .env.example not found. You need to create it manually."
            exit 1
        fi
    else
        log_info "Frontend .env file already exists."
    fi
    
    # Update production environment variables
    if [ -f "$PROJECT_DIR/packages/twenty-server/.env" ]; then
        # Set production environment
        if ! grep -q "^NODE_ENV=" "$PROJECT_DIR/packages/twenty-server/.env"; then
            echo "NODE_ENV=production" >> "$PROJECT_DIR/packages/twenty-server/.env"
        else
            sed -i 's|^NODE_ENV=.*|NODE_ENV=production|' "$PROJECT_DIR/packages/twenty-server/.env"
        fi
        
        # Ensure database URL is set properly
        if ! grep -q "^PG_DATABASE_URL=" "$PROJECT_DIR/packages/twenty-server/.env"; then
            echo "PG_DATABASE_URL=postgres://postgres:postgres@localhost:5432/default" >> "$PROJECT_DIR/packages/twenty-server/.env"
        else
            sed -i 's|^PG_DATABASE_URL=.*|PG_DATABASE_URL=postgres://postgres:postgres@localhost:5432/default|' "$PROJECT_DIR/packages/twenty-server/.env"
        fi
        
        # Ensure Redis URL is set properly
        if ! grep -q "^REDIS_URL=" "$PROJECT_DIR/packages/twenty-server/.env"; then
            echo "REDIS_URL=redis://localhost:6379" >> "$PROJECT_DIR/packages/twenty-server/.env"
        else
            sed -i 's|^REDIS_URL=.*|REDIS_URL=redis://localhost:6379|' "$PROJECT_DIR/packages/twenty-server/.env"
        fi
        
        # Ensure APP_SECRET is set (require secure secret for production)
        if ! grep -q "^APP_SECRET=" "$PROJECT_DIR/packages/twenty-server/.env" || [ "$(grep "^APP_SECRET=" "$PROJECT_DIR/packages/twenty-server/.env" | cut -d'=' -f2)" = "replace_me_with_a_random_string" ]; then
            log_error "APP_SECRET is not properly configured in server .env file. Please set a strong secret for production."
            exit 1
        fi
        
        # Ensure FRONTEND_URL is set to production domain
        if ! grep -q "^FRONTEND_URL=" "$PROJECT_DIR/packages/twenty-server/.env"; then
            log_warn "FRONTEND_URL is not set. Please update it to your production domain in server .env file."
            echo "FRONTEND_URL=http://localhost:3001" >> "$PROJECT_DIR/packages/twenty-server/.env"
        else
            sed -i 's|^FRONTEND_URL=.*|FRONTEND_URL=http://localhost:3001|' "$PROJECT_DIR/packages/twenty-server/.env"
        fi
        
        log_success "Updated server environment variables for production."
    fi
    
    if [ -f "$PROJECT_DIR/packages/twenty-front/.env" ]; then
        # Ensure server URL is set to production domain
        if ! grep -q "^REACT_APP_SERVER_BASE_URL=" "$PROJECT_DIR/packages/twenty-front/.env"; then
            log_warn "REACT_APP_SERVER_BASE_URL is not set. Please update it to your production domain in frontend .env file."
            echo "REACT_APP_SERVER_BASE_URL=http://localhost:3000" >> "$PROJECT_DIR/packages/twenty-front/.env"
        else
            sed -i 's|^REACT_APP_SERVER_BASE_URL=.*|REACT_APP_SERVER_BASE_URL=http://localhost:3000|' "$PROJECT_DIR/packages/twenty-front/.env"
        fi
        
        log_success "Updated frontend environment variables for production."
    fi
}

# Build the application for production
build_application() {
    log_info "Building application for production..."
    
    cd "$PROJECT_DIR"
    
    # Build backend
    log_info "Building backend server..."
    npx nx build twenty-server
    log_success "Backend server built successfully."
    
    # Build frontend
    log_info "Building frontend application..."
    npx nx build twenty-front
    log_success "Frontend application built successfully."
}

# Initialize the database
init_database() {
    log_info "Initializing database..."
    
    cd "$PROJECT_DIR"
    
    # Run database initialization
    npx nx run twenty-server:database:init:prod
    
    log_success "Database initialized."
}

# Main function
main() {
    echo
    log_info "==========================================="
    log_info "TWENTY CRM PRODUCTION SETUP SCRIPT"
    log_info "==========================================="
    echo
    
    log_warn "IMPORTANT: This script is for production setup."
    log_warn "Make sure all security configurations are in place before running this."
    log_warn "Especially ensure APP_SECRET is properly set in your .env files."
    echo
    
    read -p "Do you want to continue with production setup? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Production setup cancelled."
        exit 0
    fi
    
    check_prerequisites
    setup_docker_network
    start_postgres
    start_redis
    install_dependencies
    setup_env_files
    build_application
    init_database
    
    echo
    log_success "==========================================="
    log_success "TWENTY CRM PRODUCTION SETUP COMPLETED"
    log_success "==========================================="
    echo
    log_info "Setup completed successfully!"
    log_info "To run the application, use: ./run_prod.sh"
    echo
    log_info "For production use, make sure to:"
    log_info "1. Configure a reverse proxy (like Nginx) for SSL/TLS"
    log_info "2. Set up proper firewall rules"
    log_info "3. Configure backup strategies for your database"
    log_info "4. Monitor application performance and logs"
    echo
}

# Run main function
main "$@"