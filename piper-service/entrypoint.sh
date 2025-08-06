#!/bin/bash

# Piper TTS Service Entrypoint Script
# Handles initialization, graceful shutdown, and environment setup

set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${level}[$timestamp] [ENTRYPOINT] ${message}${NC}" >&2
}

# Error handler
error_exit() {
    log $RED "ERROR: $1"
    exit 1
}

# Signal handlers for graceful shutdown
shutdown() {
    log $YELLOW "Received shutdown signal, stopping Piper TTS service..."
    
    if [[ -n "$SERVICE_PID" ]]; then
        # Send SIGTERM to the service
        kill -TERM "$SERVICE_PID" 2>/dev/null || true
        
        # Wait for graceful shutdown (max 30 seconds)
        local count=0
        while kill -0 "$SERVICE_PID" 2>/dev/null && [[ $count -lt 30 ]]; do
            sleep 1
            ((count++))
        done
        
        # Force kill if still running
        if kill -0 "$SERVICE_PID" 2>/dev/null; then
            log $YELLOW "Service didn't stop gracefully, forcing shutdown..."
            kill -KILL "$SERVICE_PID" 2>/dev/null || true
        fi
    fi
    
    log $GREEN "Piper TTS service stopped"
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT SIGQUIT

log $BLUE "Starting Piper TTS Service initialization..."

# Validate environment
log $BLUE "Validating environment..."

# Check if running as non-root user
if [[ $EUID -eq 0 ]]; then
    log $YELLOW "WARNING: Running as root user - not recommended for production"
fi

# Validate required environment variables
required_vars=("PIPER_PORT" "PIPER_HOST" "PIPER_MODELS_DIR")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        error_exit "Required environment variable $var is not set"
    fi
done

# Create necessary directories
log $BLUE "Setting up directories..."
mkdir -p "$PIPER_MODELS_DIR" "$(dirname "$PIPER_LOG_FILE")" /app/tmp

# Check if models directory exists and has models
if [[ ! -d "$PIPER_MODELS_DIR" ]]; then
    error_exit "Models directory does not exist: $PIPER_MODELS_DIR"
fi

# Check if default voice model exists
default_model="$PIPER_MODELS_DIR/${PIPER_DEFAULT_VOICE}.onnx"
default_config="$PIPER_MODELS_DIR/${PIPER_DEFAULT_VOICE}.onnx.json"

if [[ ! -f "$default_model" ]] || [[ ! -f "$default_config" ]]; then
    log $YELLOW "WARNING: Default voice model not found: $PIPER_DEFAULT_VOICE"
    log $BLUE "Available models in $PIPER_MODELS_DIR:"
    ls -la "$PIPER_MODELS_DIR" | grep -E '\.(onnx|json)$' || log $YELLOW "No models found"
else
    log $GREEN "Default voice model validated: $PIPER_DEFAULT_VOICE"
fi

# Test Python imports
log $BLUE "Validating Python dependencies..."
python -c "
import sys
import piper
import fastapi
import uvicorn
import pydantic
print('All required Python packages imported successfully')
" || error_exit "Failed to import required Python packages"

# Display configuration
log $BLUE "Service Configuration:"
echo "  Host: $PIPER_HOST"
echo "  Port: $PIPER_PORT"
echo "  Models Directory: $PIPER_MODELS_DIR"
echo "  Default Voice: $PIPER_DEFAULT_VOICE"
echo "  Log Level: $LOG_LEVEL"
echo "  Log File: $PIPER_LOG_FILE"
echo "  Max Text Length: $PIPER_MAX_TEXT_LENGTH"
echo "  Max Concurrent: $PIPER_MAX_CONCURRENT"
echo "  Model Cache Size: $PIPER_MODEL_CACHE_SIZE"

# Health check function
health_check() {
    local max_attempts=30
    local attempt=1
    
    log $BLUE "Waiting for service to be ready..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s "http://localhost:$PIPER_PORT/health" >/dev/null 2>&1; then
            log $GREEN "Service is ready and responding to health checks"
            return 0
        fi
        
        log $BLUE "Attempt $attempt/$max_attempts - waiting for service startup..."
        sleep 2
        ((attempt++))
    done
    
    log $RED "Service failed to respond to health checks after $max_attempts attempts"
    return 1
}

# Start the service
log $GREEN "Starting Piper TTS Service..."

# Execute the service in the background and capture PID
if [[ "$1" == "python" && "$2" == "service.py" ]]; then
    # Default service startup
    python service.py &
    SERVICE_PID=$!
elif [[ "$1" == "dev" ]]; then
    # Development mode with auto-reload
    log $BLUE "Starting in development mode with auto-reload..."
    uvicorn service:app --host "$PIPER_HOST" --port "$PIPER_PORT" --reload --log-level debug &
    SERVICE_PID=$!
elif [[ "$1" == "test" ]]; then
    # Test mode - just validate setup and exit
    log $GREEN "Test mode - validation completed successfully"
    exit 0
else
    # Execute custom command
    exec "$@"
fi

# Wait a moment then perform health check
sleep 5
if health_check; then
    log $GREEN "Piper TTS Service started successfully (PID: $SERVICE_PID)"
    
    # Display service information
    echo ""
    log $BLUE "Service Information:"
    echo "  Service URL: http://localhost:$PIPER_PORT"
    echo "  Health Check: http://localhost:$PIPER_PORT/health"
    echo "  API Documentation: http://localhost:$PIPER_PORT/docs"
    echo "  Available Voices: http://localhost:$PIPER_PORT/voices"
    echo ""
    
    log $GREEN "Piper TTS Service is ready to accept requests"
else
    error_exit "Service failed to start properly"
fi

# Wait for the service to complete
wait $SERVICE_PID