#!/bin/bash

# Twenty CRM Development Run Script
# This script runs the Twenty CRM project in development mode
# Usage: ./run_dev.sh

set -e  # Exit on any error

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
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

# Stop existing processes
stop_existing_services() {
    log_info "Stopping existing services..."
    
    # Stop any running processes on our ports
    if is_port_in_use $BACKEND_PORT; then
        log_info "Stopping services on port $BACKEND_PORT..."
        pkill -f "twenty-server" 2>/dev/null || true
        lsof -ti:3000 | xargs kill -9 2>/dev/null || true
    fi
    
    if is_port_in_use $FRONTEND_PORT; then
        log_info "Stopping services on port $FRONTEND_PORT..."
        pkill -f "twenty-front" 2>/dev/null || true
        lsof -ti:3001 | xargs kill -9 2>/dev/null || true
    fi
    
    # Kill any related processes
    pkill -f "nx serve" 2>/dev/null || true
    pkill -f "nx start" 2>/dev/null || true
    pkill -f "concurrently" 2>/dev/null || true
    pkill -f "wait-on" 2>/dev/null || true
    
    log_info "Waiting for services to stop..."
    sleep 3
}

# Verify that setup has been completed
verify_setup() {
    log_info "Verifying setup has been completed..."
    
    if [ ! -d "$PROJECT_DIR/node_modules" ] || [ -z "$(ls -A node_modules 2>/dev/null)" ]; then
        log_error "Dependencies are not installed. Please run setup_dev.sh first."
        exit 1
    fi
    
    if [ ! -f "$PROJECT_DIR/packages/twenty-server/.env" ]; then
        log_error "Server environment file does not exist. Please run setup_dev.sh first."
        exit 1
    fi
    
    if [ ! -f "$PROJECT_DIR/packages/twenty-front/.env" ]; then
        log_error "Frontend environment file does not exist. Please run setup_dev.sh first."
        exit 1
    fi
    
    log_success "Setup verification completed."
}

# Start the application in development mode
start_dev_application() {
    log_info "Starting Twenty CRM application in development mode..."
    
    cd "$PROJECT_DIR"
    
    # Start backend server
    log_info "Starting backend server on port $BACKEND_PORT..."
    npx nx start twenty-server &
    BACKEND_PID=$!
    
    # Wait for backend to be ready
    if wait_for_port $BACKEND_PORT 60; then
        log_success "Backend server started successfully on port $BACKEND_PORT"
    else
        log_error "Backend server failed to start on port $BACKEND_PORT within 60 seconds"
        exit 1
    fi
    
    # Start frontend server
    log_info "Starting frontend server on port $FRONTEND_PORT..."
    npx nx start twenty-front &
    FRONTEND_PID=$!
    
    # Wait for frontend to be ready
    if wait_for_port $FRONTEND_PORT 60; then
        log_success "Frontend server started successfully on port $FRONTEND_PORT"
    else
        log_error "Frontend server failed to start on port $FRONTEND_PORT within 60 seconds"
        exit 1
    fi
    
    # Start background worker
    log_info "Starting background worker..."
    npx nx run twenty-server:worker &
    WORKER_PID=$!
    
    log_success "Background worker started"
    
    # Show summary
    echo
    log_success "==========================================="
    log_success "TWENTY CRM DEVELOPMENT SERVERS ARE RUNNING"
    log_success "==========================================="
    echo
    log_info "Frontend:  http://localhost:$FRONTEND_PORT"
    log_info "Backend:   http://localhost:$BACKEND_PORT"
    log_info "GraphQL:   http://localhost:$BACKEND_PORT/graphql"
    echo
    log_info "Backend PID: $BACKEND_PID"
    log_info "Frontend PID: $FRONTEND_PID"
    log_info "Worker PID: $WORKER_PID"
    echo
    log_info "Use Ctrl+C to stop the servers"
    log_success "==========================================="
    echo
}

# Main function
main() {
    echo
    log_info "==========================================="
    log_info "RUNNING TWENTY CRM IN DEVELOPMENT MODE"
    log_info "==========================================="
    echo
    
    verify_setup
    stop_existing_services
    start_dev_application
    
    # Keep the script running to maintain the servers
    echo "Services are running. Press Ctrl+C to stop."
    trap "echo; log_info 'Stopping services...'; pkill -P $; exit 0" SIGINT SIGTERM
    wait
}

# Run main function
main "$@"