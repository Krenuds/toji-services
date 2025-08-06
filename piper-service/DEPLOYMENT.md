# Piper TTS Service - Deployment Guide

This guide covers building, deploying, and managing the Piper TTS Docker service in production.

## Quick Start

### 1. Build and Run Locally

```bash
# Build and start the service
./build.sh -r

# Or using Docker Compose
docker-compose up -d

# Check service health
curl http://localhost:9001/health
```

### 2. Test the Service

```bash
# List available voices
curl http://localhost:9001/voices

# Generate speech (returns WAV audio)
curl -X POST http://localhost:9001/tts \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello, this is Piper TTS speaking!"}' \
  --output speech.wav
```

## Architecture Overview

```
[Blindr Discord Bot] --HTTP--> [Piper TTS Service:9001]
                                      |
                               [Voice Models Cache]
                                      |
                               [ONNX Runtime (CPU)]
```

### Key Features

- **CPU-Optimized**: Efficient text-to-speech without GPU requirements
- **Multi-Voice Support**: Cached voice models with on-demand downloads
- **Production Ready**: Health checks, graceful shutdown, resource limits
- **Secure**: Non-root container user, minimal attack surface
- **Scalable**: Configurable concurrency and model caching

## Build Process

### Multi-Stage Build

The Dockerfile uses a multi-stage build for optimization:

1. **Builder Stage**: Compiles dependencies, downloads default voice model
2. **Runtime Stage**: Minimal image with only runtime dependencies

### Build Options

```bash
# Standard build
./build.sh

# Build with custom tag and run
./build.sh -t v1.0.0 -r

# Force rebuild without cache
./build.sh -f

# Build and tag for registry
docker build -t your-registry.com/piper-tts:latest .
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIPER_HOST` | `0.0.0.0` | Service bind address |
| `PIPER_PORT` | `9001` | Service port |
| `PIPER_MODELS_DIR` | `/app/models/piper` | Voice models directory |
| `PIPER_DEFAULT_VOICE` | `en_US-lessac-medium` | Default voice model |
| `PIPER_MAX_TEXT_LENGTH` | `10000` | Maximum text length |
| `PIPER_MAX_CONCURRENT` | `10` | Max concurrent requests |
| `PIPER_MODEL_CACHE_SIZE` | `5` | Number of models to cache |
| `LOG_LEVEL` | `INFO` | Logging level |
| `PIPER_LOG_FILE` | `/app/logs/piper-service.log` | Log file path |

### Volume Mounts

| Path | Purpose | Required |
|------|---------|----------|
| `/app/models/piper` | Voice model cache | Optional* |
| `/app/logs` | Service logs | Optional |
| `/app/tmp` | Temporary files | Optional |

*Models are cached in the Docker image, but external volumes allow for persistent storage and additional models.

## Deployment Options

### 1. Docker Compose (Recommended for Development)

```yaml
# Use the included docker-compose.yml
docker-compose up -d

# View logs
docker-compose logs -f piper-service

# Scale the service
docker-compose up -d --scale piper-service=3
```

### 2. Systemd Service (Production)

```bash
# Install the systemd service
sudo cp piper-tts.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable and start
sudo systemctl enable piper-tts.service
sudo systemctl start piper-tts.service

# Check status
sudo systemctl status piper-tts.service
```

### 3. Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: piper-tts-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: piper-tts
  template:
    metadata:
      labels:
        app: piper-tts
    spec:
      containers:
      - name: piper-tts
        image: piper-tts-service:latest
        ports:
        - containerPort: 9001
        env:
        - name: PIPER_PORT
          value: "9001"
        - name: LOG_LEVEL
          value: "INFO"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 9001
          initialDelaySeconds: 45
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 9001
          initialDelaySeconds: 15
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: piper-tts-service
spec:
  selector:
    app: piper-tts
  ports:
  - port: 9001
    targetPort: 9001
  type: ClusterIP
```

## Monitoring and Maintenance

### Health Checks

The service provides comprehensive health monitoring:

```bash
# Basic health check
curl http://localhost:9001/health

# Detailed response includes:
# - Service status
# - Loaded voice models count
# - Default voice configuration
# - Models directory path
```

### Logging

Logs are available through multiple channels:

```bash
# Docker logs
docker logs -f piper-tts-service

# Systemd logs
sudo journalctl -u piper-tts.service -f

# Application log file (if volume mounted)
tail -f /path/to/logs/piper-service.log
```

### Performance Monitoring

Key metrics to monitor:

- **Response Time**: TTS generation latency
- **Memory Usage**: Voice model cache size
- **CPU Usage**: Audio processing load
- **Request Rate**: Concurrent TTS requests
- **Error Rate**: Failed TTS generations

### Voice Model Management

```bash
# List available voices
curl http://localhost:9001/voices

# Download new voice model
curl -X POST http://localhost:9001/download-voice \
  -H "Content-Type: application/json" \
  -d '{"voice_name":"en_GB-alan-medium"}'

# Models are automatically cached after first use
```

## Security Considerations

### Container Security

- **Non-root User**: Service runs as user `piper` (UID 1001)
- **Read-only Root**: Filesystem is read-only except for specific directories
- **Resource Limits**: Memory and CPU limits prevent resource exhaustion
- **Network Isolation**: Only exposes necessary port 9001

### Production Hardening

1. **Reverse Proxy**: Use nginx or similar for TLS termination
2. **Rate Limiting**: Implement request rate limiting
3. **Authentication**: Add API key authentication if needed
4. **Firewall**: Restrict network access to required sources only

### Example Nginx Configuration

```nginx
upstream piper-tts {
    server 127.0.0.1:9001;
}

server {
    listen 80;
    server_name piper-tts.yourdomain.com;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=tts:10m rate=10r/m;
    limit_req zone=tts burst=5 nodelay;
    
    location / {
        proxy_pass http://piper-tts;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Increase timeout for TTS generation
        proxy_read_timeout 60s;
        proxy_connect_timeout 10s;
    }
    
    location /health {
        proxy_pass http://piper-tts/health;
        access_log off;
    }
}
```

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   ```bash
   # Check Docker daemon
   sudo systemctl status docker
   
   # Check container logs
   docker logs piper-tts-service
   
   # Verify port availability
   sudo netstat -tlnp | grep 9001
   ```

2. **Voice Model Download Fails**
   ```bash
   # Check network connectivity
   curl -I https://huggingface.co
   
   # Manual model download
   wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx
   ```

3. **High Memory Usage**
   ```bash
   # Check model cache size
   curl http://localhost:9001/health
   
   # Reduce cache size
   docker run -e PIPER_MODEL_CACHE_SIZE=2 ...
   ```

4. **Slow TTS Generation**
   ```bash
   # Check CPU usage
   docker stats piper-tts-service
   
   # Increase CPU limit
   docker run --cpus=2.0 ...
   ```

### Performance Tuning

- **Model Selection**: Use `low` quality models for faster generation
- **Concurrency**: Adjust `PIPER_MAX_CONCURRENT` based on CPU cores
- **Cache Size**: Balance memory usage vs. model loading time
- **Text Length**: Split long texts into smaller chunks

## Integration with Blindr Bot

The service is designed to integrate seamlessly with the Blindr Discord bot:

```python
# Example integration code
import aiohttp

async def synthesize_speech(text: str, voice: str = None) -> bytes:
    """Generate speech using Piper TTS service."""
    async with aiohttp.ClientSession() as session:
        payload = {"text": text}
        if voice:
            payload["voice"] = voice
            
        async with session.post(
            "http://localhost:9001/tts",
            json=payload
        ) as response:
            if response.status == 200:
                return await response.read()
            else:
                raise Exception(f"TTS failed: {response.status}")
```

## Backup and Recovery

### Voice Models Backup

```bash
# Backup voice models
docker run --rm -v piper-models:/models alpine tar czf - -C /models . > piper-models-backup.tar.gz

# Restore voice models
docker run --rm -v piper-models:/models alpine tar xzf - -C /models < piper-models-backup.tar.gz
```

### Configuration Backup

```bash
# Backup service configuration
cp docker-compose.yml piper-tts.service /backup/location/

# Backup environment variables
env | grep PIPER_ > piper-env-backup.txt
```

## Updates and Maintenance

### Updating the Service

```bash
# Build new image
./build.sh -t latest

# Update running service
docker-compose up -d

# Or with systemd
sudo systemctl restart piper-tts.service
```

### Model Updates

New voice models are automatically available through the catalog. To add custom models:

1. Place `.onnx` and `.onnx.json` files in the models directory
2. Update the voice catalog in `config.py`
3. Rebuild and redeploy the service

This deployment guide ensures reliable, scalable operation of the Piper TTS service in production environments while maintaining compatibility with the Blindr voice assistant ecosystem.