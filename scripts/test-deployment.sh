#!/bin/bash
# Test script for Blindr Services deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Blindr Services Deployment Test${NC}"
echo "================================="
echo

# Test 1: Environment check
echo -e "${YELLOW}[1/6] Checking environment...${NC}"
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo "Run 'make setup' first"
    exit 1
fi
echo -e "${GREEN}✓ Environment file exists${NC}"

# Test 2: Docker availability
echo -e "${YELLOW}[2/6] Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is available${NC}"

# Test 3: Docker Compose availability
echo -e "${YELLOW}[3/6] Checking Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found${NC}"
    exit 1
fi

# Validate compose file
if ! docker-compose config --quiet; then
    echo -e "${RED}❌ Docker Compose configuration invalid${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose is ready${NC}"

# Test 4: GPU availability (if needed)
echo -e "${YELLOW}[4/6] Checking GPU support...${NC}"
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ NVIDIA GPU detected${NC}"
        GPU_AVAILABLE=true
    else
        echo -e "${YELLOW}⚠ NVIDIA GPU not accessible${NC}"
        GPU_AVAILABLE=false
    fi
else
    echo -e "${YELLOW}⚠ nvidia-smi not found${NC}"
    GPU_AVAILABLE=false
fi

# Test 5: Port availability
echo -e "${YELLOW}[5/6] Checking port availability...${NC}"
WHISPER_PORT=$(grep WHISPER_PORT .env | cut -d= -f2 | tr -d ' ')
PIPER_PORT=$(grep PIPER_PORT .env | cut -d= -f2 | tr -d ' ')

# Default ports if not found in .env
WHISPER_PORT=${WHISPER_PORT:-9000}
PIPER_PORT=${PIPER_PORT:-9001}

if netstat -tulpn 2>/dev/null | grep -q ":$WHISPER_PORT "; then
    echo -e "${RED}❌ Port $WHISPER_PORT is already in use${NC}"
    exit 1
fi

if netstat -tulpn 2>/dev/null | grep -q ":$PIPER_PORT "; then
    echo -e "${RED}❌ Port $PIPER_PORT is already in use${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Ports $WHISPER_PORT and $PIPER_PORT are available${NC}"

# Test 6: Disk space
echo -e "${YELLOW}[6/6] Checking disk space...${NC}"
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
REQUIRED_SPACE=10485760  # 10GB in KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo -e "${RED}❌ Insufficient disk space (need at least 10GB)${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Sufficient disk space available${NC}"

echo
echo -e "${GREEN}All pre-deployment checks passed!${NC}"
echo
echo "Configuration Summary:"
echo "  Whisper Port: $WHISPER_PORT"
echo "  Piper Port: $PIPER_PORT"
echo "  GPU Support: $GPU_AVAILABLE"
echo "  Data Directory: $(pwd)/data"
echo

# Optional: Quick deployment test
read -p "Would you like to run a quick deployment test? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Starting deployment test...${NC}"
    
    # Start services
    echo "Starting services..."
    docker-compose up -d whisper-service piper-service
    
    # Wait for services to start
    echo "Waiting for services to initialize..."
    sleep 30
    
    # Test health endpoints
    echo "Testing Whisper service..."
    if curl -s -f "http://localhost:$WHISPER_PORT/health" > /dev/null; then
        echo -e "${GREEN}✓ Whisper service is healthy${NC}"
    else
        echo -e "${RED}❌ Whisper service health check failed${NC}"
    fi
    
    echo "Testing Piper service..."
    if curl -s -f "http://localhost:$PIPER_PORT/health" > /dev/null; then
        echo -e "${GREEN}✓ Piper service is healthy${NC}"
    else
        echo -e "${RED}❌ Piper service health check failed${NC}"
    fi
    
    # Show status
    echo
    echo "Service Status:"
    docker-compose ps
    
    echo
    read -p "Keep services running? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Stopping test services..."
        docker-compose down
    else
        echo -e "${GREEN}Services are running and ready!${NC}"
        echo
        echo "Access URLs:"
        echo "  Whisper: http://localhost:$WHISPER_PORT"
        echo "  Piper: http://localhost:$PIPER_PORT"
        echo
        echo "To stop services: make down"
    fi
fi

echo
echo -e "${GREEN}Deployment test completed!${NC}"