#!/bin/bash

# Piper TTS Service Build Script
# Builds and optionally runs the Piper TTS Docker container

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="piper-tts-service"
TAG="latest"
BUILD_ARGS=""
RUN_AFTER_BUILD=false
FORCE_REBUILD=false

# Function to print colored output
log() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] ${message}${NC}"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --tag TAG        Docker image tag (default: latest)"
    echo "  -n, --name NAME      Docker image name (default: piper-tts-service)"
    echo "  -r, --run            Run container after successful build"
    echo "  -f, --force          Force rebuild (no cache)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   Build with default settings"
    echo "  $0 -t v1.0.0 -r     Build with tag v1.0.0 and run"
    echo "  $0 -f                Force rebuild without cache"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -r|--run)
            RUN_AFTER_BUILD=true
            shift
            ;;
        -f|--force)
            FORCE_REBUILD=true
            BUILD_ARGS="--no-cache"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log $RED "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required files
log $BLUE "Validating build environment..."

required_files=("Dockerfile" "requirements.txt" "service.py" "config.py")
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        log $RED "Required file missing: $file"
        exit 1
    fi
done

log $GREEN "All required files present"

# Show build configuration
log $BLUE "Build Configuration:"
echo "  Image Name: $IMAGE_NAME"
echo "  Tag: $TAG"
echo "  Force Rebuild: $FORCE_REBUILD"
echo "  Run After Build: $RUN_AFTER_BUILD"
echo ""

# Build the Docker image
log $BLUE "Starting Docker build..."

FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"

if docker build $BUILD_ARGS -t "$FULL_IMAGE_NAME" .; then
    log $GREEN "Docker build completed successfully"
    
    # Show image information
    IMAGE_SIZE=$(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep "$IMAGE_NAME" | grep "$TAG" | awk '{print $3}')
    log $BLUE "Built image: $FULL_IMAGE_NAME ($IMAGE_SIZE)"
    
else
    log $RED "Docker build failed"
    exit 1
fi

# Run the container if requested
if [[ "$RUN_AFTER_BUILD" == true ]]; then
    log $BLUE "Starting container..."
    
    CONTAINER_NAME="${IMAGE_NAME}-container"
    
    # Stop and remove existing container if it exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log $YELLOW "Stopping existing container: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Run the new container
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p 9001:9001 \
        --restart unless-stopped \
        "$FULL_IMAGE_NAME"
    
    log $GREEN "Container started: $CONTAINER_NAME"
    
    # Wait a moment and check health
    log $BLUE "Waiting for service to start..."
    sleep 10
    
    if curl -f http://localhost:9001/health >/dev/null 2>&1; then
        log $GREEN "Service health check passed!"
        log $BLUE "Service is available at: http://localhost:9001"
        echo ""
        echo "API Endpoints:"
        echo "  Health Check: http://localhost:9001/health"
        echo "  List Voices:  http://localhost:9001/voices" 
        echo "  Text-to-Speech: POST http://localhost:9001/tts"
        echo ""
        echo "View logs with: docker logs -f $CONTAINER_NAME"
    else
        log $YELLOW "Service health check failed - check logs:"
        echo "  docker logs $CONTAINER_NAME"
    fi
fi

log $GREEN "Build script completed successfully!"

# Show next steps
echo ""
log $BLUE "Next Steps:"
if [[ "$RUN_AFTER_BUILD" != true ]]; then
    echo "  Run container:    docker run -d -p 9001:9001 --name piper-service $FULL_IMAGE_NAME"
fi
echo "  View logs:        docker logs -f ${IMAGE_NAME}-container"
echo "  Stop container:   docker stop ${IMAGE_NAME}-container"
echo "  Remove container: docker rm ${IMAGE_NAME}-container"
echo "  Push to registry: docker push $FULL_IMAGE_NAME"