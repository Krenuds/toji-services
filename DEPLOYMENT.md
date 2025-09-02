# Toji Services Deployment Guide

## CRITICAL LESSONS LEARNED - READ FIRST

### Docker Installation Warning
**DO NOT USE SNAP-INSTALLED DOCKER** - It does not support GPU passthrough to containers. This was a major issue that caused GPU detection failures. Always use Docker CE from the official repository.

### Key Issues We Encountered and Solutions
1. **Snap Docker blocks GPU access** - Remove snap Docker, install Docker CE
2. **NVIDIA runtime not configured** - Must edit /etc/docker/daemon.json
3. **Network conflicts** - Remove old Docker networks before deployment
4. **Container name conflicts** - Remove old containers before redeployment

This guide provides comprehensive instructions for deploying the Toji (formerly Blindr) speech processing services with proper GPU support.

## Table of Contents
- [Critical Setup Steps](#critical-setup-steps)
- [Quick Start](#quick-start)  
- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Service Configuration](#service-configuration)
- [Deployment Options](#deployment-options)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)
- [Production Considerations](#production-considerations)

## Critical Setup Steps

### 1. Remove Snap Docker and Install Docker CE

```bash
# Check if Docker is from snap (BAD)
which docker
# If output is /snap/bin/docker, remove it:
sudo snap remove docker

# Install Docker CE properly
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Configure NVIDIA Runtime (CRITICAL FOR GPU)

```bash
# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker daemon for NVIDIA runtime
sudo tee /etc/docker/daemon.json <<EOF
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "args": [],
            "path": "nvidia-container-runtime"
        }
    }
}
EOF

# Restart Docker
sudo systemctl restart docker

# VERIFY GPU ACCESS (This must work!)
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## Quick Start

After completing critical setup:

```bash
# 1. Clone repository
cd /home/travis/services
git clone https://github.com/Krenuds/toji-services.git
cd toji-services

# 2. Create environment file
cp .env.example .env
nano .env  # Edit as needed

# 3. Use existing data (if available)
cat > docker-compose.override.yml <<EOF
version: '3.8'
services:
  whisper-service:
    volumes:
      - /home/travis/services/data/whisper/models:/app/models
      - /home/travis/services/data/whisper/logs:/app/logs
      - /tmp:/tmp
  piper-service:
    volumes:
      - /home/travis/services/data/piper/models:/app/models
      - /home/travis/services/data/piper/logs:/app/logs
      - /home/travis/services/data/piper/cache:/app/cache
EOF

# 4. Build and start services
docker-compose build
docker-compose up -d

# 5. Verify GPU is being used
curl -s http://localhost:9000/health | python3 -m json.tool
# Should show "device": "cuda"
```

## Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ or similar Linux distribution
- **Memory**: Minimum 16GB RAM (32GB recommended for production)
- **Storage**: 50GB+ free space for models and logs
- **GPU**: NVIDIA GPU with CUDA support (for Whisper acceleration)
- **Network**: Ports 9000, 9001 available (and 80, 443 for production)

### Software Dependencies

**CRITICAL**: See [Critical Setup Steps](#critical-setup-steps) above for proper Docker and NVIDIA runtime installation. Do NOT use snap Docker or skip the daemon.json configuration.

## Environment Setup

### 1. Initialize Configuration
```bash
make setup
```
This creates:
- `.env` file from template
- Required data directories
- Basic infrastructure directories

### 2. Customize Environment Variables

Edit `.env` file to match your environment:

```bash
# Essential settings to review:
WHISPER_MODEL_SIZE=small          # tiny/base/small/medium/large-v2/large-v3
CUDA_VISIBLE_DEVICES=0            # GPU ID to use
PIPER_DEFAULT_VOICE=en_US-amy-medium
LOG_LEVEL=info                    # debug/info/warning/error

# Port configuration (if defaults conflict)
WHISPER_PORT=9000
PIPER_PORT=9001

# Data persistence paths
WHISPER_MODELS_PATH=./data/whisper/models
PIPER_MODELS_PATH=./data/piper/models
```

### 3. Validate Configuration
```bash
make check-env
```

## Service Configuration

### Whisper Service (Speech-to-Text)
- **Purpose**: Converts audio to text using OpenAI's Whisper model
- **GPU Usage**: High (requires CUDA-compatible GPU)
- **Memory**: 2-8GB depending on model size
- **Models Available**: 
  - `tiny`: Fastest, least accurate (~1GB VRAM)
  - `small`: Balanced performance (~2GB VRAM)
  - `medium`: Better accuracy (~5GB VRAM)
  - `large-v3`: Best accuracy (~10GB VRAM)

### Piper Service (Text-to-Speech)
- **Purpose**: Converts text to natural speech using Piper TTS
- **GPU Usage**: None (CPU-based)
- **Memory**: 1-4GB depending on voice models
- **Voice Models**: Downloads automatically on first use

## Deployment Options

### Development Deployment
For development and testing:
```bash
make up
```
This starts:
- Whisper service on port 9000
- Piper service on port 9001
- Basic health checks and logging

### Production Deployment
For production with reverse proxy:
```bash
make up-prod
```
This includes:
- All core services
- Nginx reverse proxy (ports 80, 443)
- SSL termination
- Rate limiting
- Load balancing ready

### Full Monitoring Stack
For production with monitoring:
```bash
make up-all
```
This includes everything plus:
- Prometheus monitoring
- Service metrics collection
- Performance dashboards ready

### Custom Profiles
Start specific combinations:
```bash
# Core services only
docker-compose up -d whisper-service piper-service

# With nginx proxy
docker-compose --profile production up -d

# With monitoring
docker-compose --profile monitoring up -d
```

## SSL Certificate Setup (Production)

### Option 1: Self-Signed Certificates (Development)
```bash
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
```

### Option 2: Let's Encrypt (Production)
```bash
# Install certbot
sudo apt-get install certbot

# Get certificate (replace your-domain.com)
sudo certbot certonly --standalone -d your-domain.com

# Copy certificates
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem nginx/ssl/key.pem
sudo chown $USER:$USER nginx/ssl/*.pem
```

## Service Management

### Common Operations
```bash
# View service status
make status

# View logs (all services)
make logs

# View logs (specific service)
make logs service=whisper-service

# Restart all services
make restart

# Restart specific service
make restart-service service=piper-service

# Health check
make health

# Test connectivity
make test
```

### Scaling Services
Edit `docker-compose.yml` to add replicas:
```yaml
whisper-service:
  deploy:
    replicas: 2  # Run 2 instances
```

Or use Docker Compose scaling:
```bash
docker-compose up -d --scale whisper-service=2
```

## Monitoring and Maintenance

### Health Monitoring
Services provide health endpoints:
- Whisper: `http://localhost:9000/health`
- Piper: `http://localhost:9001/health`
- Combined: `make health`

### Log Management
```bash
# View recent logs
make logs-tail

# Debug mode with verbose logging
make debug

# Log rotation is automatic (see docker-compose.yml logging config)
```

### Performance Monitoring
If using monitoring profile:
- Prometheus: `http://localhost:9090`
- Metrics endpoints: `/metrics` on each service
- Custom dashboards can be added to Grafana

### Backup and Recovery
```bash
# Create backup
make backup

# Manual backup
tar -czf backup-$(date +%Y%m%d).tar.gz data/ .env nginx/ monitoring/
```

### Updates and Maintenance
```bash
# Update service images
make update

# Rebuild from source
make rebuild

# Clean unused resources
make clean
```

## Troubleshooting

### Common Issues

#### GPU Not Detected (Most Common Issue)

**Primary Cause**: Snap-installed Docker or missing NVIDIA runtime configuration.

**Solution Checklist**:
1. Verify Docker is NOT from snap:
   ```bash
   which docker  # Should NOT be /snap/bin/docker
   ```
   
2. Check NVIDIA runtime is configured:
   ```bash
   cat /etc/docker/daemon.json
   # Must contain "default-runtime": "nvidia"
   ```
   
3. Test GPU access directly:
   ```bash
   docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
   ```
   
4. If still failing, completely reinstall Docker following [Critical Setup Steps](#critical-setup-steps)

#### GPU Not Detected (Legacy)
```bash
# Check GPU availability
nvidia-smi

# Verify Docker GPU runtime
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi

# Check container GPU access
make shell service=whisper-service
nvidia-smi
```

#### Service Won't Start
```bash
# Check logs
make logs service=whisper-service

# Verify configuration
make check-env

# Check disk space
df -h

# Check memory
free -h
```

#### Model Download Issues
```bash
# Check network connectivity
curl -I https://huggingface.co

# Manual model download (if needed)
docker-compose exec whisper-service python -c "from faster_whisper import WhisperModel; WhisperModel('small')"
```

#### Port Conflicts
```bash
# Check port usage
sudo netstat -tulpn | grep :9000

# Modify ports in .env
WHISPER_PORT=9002
PIPER_PORT=9003
```

### Debug Mode
```bash
# Start with debug logging
LOG_LEVEL=debug make up

# Or use debug command
make debug
```

## Production Considerations

### Security
1. **Firewall Configuration**:
   ```bash
   sudo ufw allow 80
   sudo ufw allow 443
   sudo ufw deny 9000  # Block direct service access
   sudo ufw deny 9001
   ```

2. **SSL/TLS**: Use valid certificates (Let's Encrypt recommended)

3. **Rate Limiting**: Configured in nginx (see nginx.conf)

4. **Access Control**: Consider VPN or IP restrictions for admin endpoints

### Performance Optimization
1. **GPU Memory**: Monitor VRAM usage, adjust model size if needed
2. **CPU Resources**: Piper service benefits from multiple cores
3. **Storage**: Use SSD storage for model files
4. **Network**: Consider CDN for static content

### High Availability
1. **Multiple Instances**: Scale services horizontally
2. **Health Checks**: Configure external monitoring (Prometheus + Grafana)
3. **Auto-restart**: Services restart automatically on failure
4. **Load Balancing**: Nginx handles load distribution

### Monitoring Setup
1. **Prometheus Metrics**: Enable metrics collection
2. **Log Aggregation**: Consider ELK stack for centralized logging
3. **Alerting**: Set up alerts for service failures
4. **Performance Metrics**: Monitor response times and throughput

### Backup Strategy
1. **Regular Backups**: Automate daily backups of data/ directory
2. **Configuration Backup**: Version control .env and config files
3. **Model Persistence**: Models are cached in volumes
4. **Recovery Testing**: Test restore procedures regularly

## Integration with Toji/Blindr Bot

The services are designed to be drop-in replacements for the embedded components in the Toji (formerly Blindr) bot. To integrate:

1. **Update Bot Configuration**:
   ```python
   # In bot config
   WHISPER_API_URL = "http://localhost:9000"
   PIPER_API_URL = "http://localhost:9001"
   ```

2. **Test Integration**:
   ```bash
   cd /home/travis/toji  # or /home/travis/blindr
   ./toji start  # Should connect to dockerized services
   ```

3. **Monitor Performance**: Compare performance with embedded versions

## Support and Maintenance

### Regular Maintenance Tasks
- [ ] Weekly: Check service health and logs
- [ ] Monthly: Update service images
- [ ] Quarterly: Review resource usage and scaling needs
- [ ] Yearly: Security audit and certificate renewal

### Getting Help
- Check logs first: `make logs`
- Verify configuration: `make check-env`
- Test connectivity: `make test`
- Review this documentation
- Check Docker Compose logs: `docker-compose logs`

For persistent issues, collect diagnostic information:
```bash
make status > diagnostics.txt
make health >> diagnostics.txt
docker system df >> diagnostics.txt
free -h >> diagnostics.txt
nvidia-smi >> diagnostics.txt
```