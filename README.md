# Blindr Services - Speech Processing Infrastructure

This repository contains dockerized speech processing services extracted from the [blindr voice assistant](https://github.com/yourusername/blindr) project. These services provide Speech-to-Text (STT) and Text-to-Speech (TTS) capabilities via HTTP APIs.

## Services

### Whisper Service (STT)
- **Port**: 9000
- **Endpoint**: `POST /asr`
- **Description**: GPU-accelerated speech recognition using OpenAI Whisper
- **Features**:
  - Multiple output formats (txt, json, vtt, srt)
  - Language detection
  - GPU/CPU fallback
  - Real-time transcription

### Piper Service (TTS)
- **Port**: 9001
- **Endpoint**: `POST /tts`
- **Description**: Natural voice synthesis using Piper
- **Features**:
  - Multiple voice models
  - Streaming audio output
  - Low latency synthesis
  - GPU acceleration support

## Quick Start

### Using Docker Compose (Recommended)
```bash
# Start both services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Individual Service Management
```bash
# Whisper only
docker run -d -p 9000:9000 --gpus all blindr/whisper-service

# Piper only
docker run -d -p 9001:9001 --gpus all blindr/piper-service
```

## API Documentation

### Whisper STT API

#### Transcribe Audio
```bash
curl -X POST http://localhost:9000/asr \
  -F "audio_file=@audio.wav" \
  -F "language=en" \
  -F "output=json"
```

#### Health Check
```bash
curl http://localhost:9000/health
```

### Piper TTS API

#### Generate Speech
```bash
curl -X POST http://localhost:9001/tts \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, world!"}' \
  --output speech.wav
```

#### List Available Voices
```bash
curl http://localhost:9001/voices
```

## System Requirements

- Docker and Docker Compose
- NVIDIA GPU with CUDA support (optional, falls back to CPU)
- 8GB+ RAM recommended
- 10GB+ disk space for models

## GPU Support

Both services automatically detect and use GPU if available:
- NVIDIA GPUs with CUDA 11.0+
- Requires nvidia-docker runtime
- Falls back to CPU if GPU unavailable

## Configuration

### Environment Variables
```bash
# Whisper
WHISPER_PORT=9000
WHISPER_MODEL_SIZE=small
WHISPER_DEVICE=cuda  # or cpu

# Piper
PIPER_PORT=9001
PIPER_MODEL=en_US-lessac-medium
PIPER_DEVICE=cuda  # or cpu

# Shared
LOG_LEVEL=info
CUDA_VISIBLE_DEVICES=0
```

### Docker Compose Override
Create `docker-compose.override.yml` for local settings:
```yaml
version: '3.8'
services:
  whisper:
    environment:
      - WHISPER_MODEL_SIZE=medium
  piper:
    environment:
      - PIPER_MODEL=en_US-amy-low
```

## Monitoring

### Service Health
```bash
# Check all services
curl http://localhost:9000/health
curl http://localhost:9001/health

# Docker health status
docker-compose ps
```

### Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f whisper
docker-compose logs -f piper
```

## Integration with Blindr Bot

These services are designed to work with the blindr Discord bot:

```python
# In your blindr bot configuration
WHISPER_URL = "http://localhost:9000"
PIPER_URL = "http://localhost:9001"
```

## Troubleshooting

### GPU Not Detected
```bash
# Check NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

# Check Docker GPU support
docker run --rm --gpus all ubuntu nvidia-smi
```

### Out of Memory
- Reduce model size in environment variables
- Use CPU mode for one service
- Increase Docker memory limits

### Connection Refused
- Ensure services are running: `docker-compose ps`
- Check firewall rules
- Verify port bindings: `netstat -tlnp | grep 900`

## Development

### Building from Source
```bash
# Build all services
docker-compose build

# Build specific service
docker-compose build whisper
```

### Running Tests
```bash
# Run test suite
./scripts/test.sh

# Test individual service
docker-compose run whisper pytest
```

## License

This project is part of the blindr ecosystem and follows the same licensing terms.

## Support

For issues specific to these services, please open an issue in this repository.
For blindr bot integration issues, refer to the main [blindr repository](https://github.com/yourusername/blindr).