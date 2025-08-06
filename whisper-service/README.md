# Whisper Service - Production Docker Container

A production-ready, GPU-accelerated Whisper speech recognition service built with FastAPI and Docker.

## Features

- **GPU Acceleration**: NVIDIA CUDA support with automatic CPU fallback
- **Production Ready**: Multi-stage Docker builds, non-root user, health checks
- **API Compatible**: Compatible with whisper-asr-webservice API
- **Security**: Runs as non-root user with minimal privileges
- **Monitoring**: Built-in health checks and structured logging
- **Resource Efficient**: Optimized CUDA memory management

## Quick Start

1. **Build the container:**
   ```bash
   ./build.sh
   ```

2. **Start the service:**
   ```bash
   docker-compose up -d
   ```

3. **Test the service:**
   ```bash
   curl http://localhost:9000/health
   ```

## GPU Requirements

- **NVIDIA GPU** with CUDA support
- **Docker with NVIDIA Container Toolkit** installed
- **At least 2GB VRAM** for the small model (recommended)

## API Endpoints

### POST /asr
Transcribe audio to text
- **File**: Audio file (WAV, MP3, MP4, M4A, FLAC, OGG)
- **Parameters**: task, language, initial_prompt, output format

### POST /detect-language
Detect audio language
- **File**: Audio file

### GET /health
Service health check

### GET /
Service information and endpoints

## Configuration

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
```

### Key Settings:

- `WHISPER_MODEL_SIZE`: Model size (tiny, base, small, medium, large-v3)
- `CUDA_VISIBLE_DEVICES`: GPU selection
- `LOG_LEVEL`: Logging level (INFO, DEBUG, ERROR)

### Model Size Guide:

| Model | VRAM Usage | Speed | Accuracy |
|-------|------------|--------|----------|
| tiny  | ~39MB      | Fastest | Basic    |
| base  | ~74MB      | Fast    | Good     |
| small | ~461MB     | Medium  | Better   |
| medium| ~1.42GB    | Slower  | Great    |
| large-v3| ~2.87GB  | Slowest | Best     |

## Deployment

### Docker Compose (Recommended)
```bash
docker-compose up -d
```

### Manual Docker Run
```bash
docker run -d \
  --name whisper-service \
  --gpus all \
  -p 9000:9000 \
  -e WHISPER_MODEL_SIZE=small \
  whisper-service:latest
```

### Without GPU
```bash
docker run -d \
  --name whisper-service \
  -p 9000:9000 \
  -e CUDA_VISIBLE_DEVICES="" \
  whisper-service:latest
```

## Testing

### Basic Health Check
```bash
curl http://localhost:9000/health
```

### Transcribe Audio File
```bash
curl -X POST \
  -F "audio_file=@audio.wav" \
  -F "output=json" \
  http://localhost:9000/asr
```

### Language Detection
```bash
curl -X POST \
  -F "audio_file=@audio.wav" \
  http://localhost:9000/detect-language
```

## Integration with Blindr Bot

This service is designed to replace the embedded Whisper functionality in the Blindr voice assistant. The API is backward compatible.

Update Blindr configuration:
```python
WHISPER_SERVICE_URL = "http://localhost:9000"
```

## Resource Management

- **Memory**: Automatic CUDA memory cleanup on shutdown
- **Models**: Cached in persistent volumes
- **Temp Files**: Stored in tmpfs for performance
- **Logging**: Rotating logs with size limits

## Security Features

- Runs as non-root user (UID 1001)
- Read-only container filesystem
- Minimal Linux capabilities
- No unnecessary packages in runtime image

## Monitoring

View logs:
```bash
docker-compose logs -f whisper-service
```

Monitor resource usage:
```bash
docker stats whisper-service
```

## Troubleshooting

### GPU Not Detected
1. Verify NVIDIA Container Toolkit installation
2. Check `nvidia-smi` output
3. Ensure Docker has GPU access: `docker run --rm --gpus all nvidia/cuda:12.1-base nvidia-smi`

### Out of Memory
1. Use smaller model size
2. Adjust `CUDA_VISIBLE_DEVICES`
3. Monitor with `nvidia-smi`

### Build Issues
1. Ensure sufficient disk space (>10GB)
2. Check Docker BuildKit is enabled
3. Verify internet connectivity for downloads