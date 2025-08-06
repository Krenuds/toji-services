# Piper TTS Service

A production-ready HTTP API service for text-to-speech synthesis using Piper TTS.

## Overview

This service converts the embedded Piper client library from the blindr project into a standalone HTTP service. It provides RESTful endpoints for text-to-speech generation, voice management, and health monitoring.

## Features

- **RESTful API**: Clean HTTP endpoints following FastAPI best practices
- **Multiple Voices**: Support for various languages, speakers, and quality levels  
- **Async Processing**: Non-blocking audio generation using asyncio
- **Model Management**: Automatic download and caching of voice models
- **Health Monitoring**: Service status and diagnostics endpoints
- **Configuration**: Environment-based configuration with validation
- **Production Ready**: Structured logging, error handling, and performance optimization

## Quick Start

### Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Copy and customize configuration
cp .env.example .env
# Edit .env with your preferred settings
```

### Running the Service

```bash
# Using the startup script (recommended)
python start.py

# Or directly with uvicorn
uvicorn service:app --host 0.0.0.0 --port 9001
```

The service will start on `http://localhost:9001` by default.

## API Endpoints

### POST /tts
Generate speech from text.

**Request:**
```json
{
  "text": "Hello, world!",
  "voice": "en_US-lessac-medium",
  "speed": 1.0
}
```

**Response:** WAV audio data with `audio/wav` content-type.

### GET /voices
List all available voice models.

**Response:**
```json
[
  {
    "name": "en_US-lessac-medium",
    "language": "English (US)", 
    "speaker": "Lessac",
    "quality": "medium",
    "sample_rate": 22050,
    "gender": "female",
    "file_size_mb": 45.2,
    "available": true
  }
]
```

### GET /health
Service health check.

**Response:**
```json
{
  "status": "healthy",
  "voice_models_loaded": 2,
  "default_voice": "en_US-lessac-medium",
  "models_directory": "/app/models/piper"
}
```

### POST /download-voice
Download a new voice model.

**Request:**
```json
{
  "voice_name": "en_US-amy-medium"
}
```

## Configuration

Configure the service using environment variables or a `.env` file:

```bash
# Server Configuration
PIPER_HOST=0.0.0.0               # Server bind address
PIPER_PORT=9001                  # Server port

# Model Configuration  
PIPER_MODELS_DIR=models/piper    # Model storage directory
PIPER_DEFAULT_VOICE=en_US-lessac-medium  # Default voice
PIPER_MAX_TEXT_LENGTH=10000      # Maximum text length

# Performance Settings
PIPER_MAX_CONCURRENT=10          # Max concurrent requests
PIPER_MODEL_CACHE_SIZE=5         # Number of models to cache

# Logging
LOG_LEVEL=INFO                   # Log level (DEBUG/INFO/WARNING/ERROR)
PIPER_LOG_FILE=logs/piper-service.log  # Log file path
```

## Available Voices

The service supports multiple voice models with different languages, speakers, and quality levels:

### English (US)
- `en_US-lessac-medium` - Female, natural quality
- `en_US-lessac-low` - Female, smaller file size
- `en_US-amy-medium` - Female, alternative voice
- `en_US-danny-low` - Male, compact model

### English (GB)  
- `en_GB-alan-medium` - Male, British accent
- `en_GB-alan-low` - Male, British accent, compact

### Other Languages
- `es_ES-marta-medium` - Spanish (Spain), female
- `fr_FR-upmc-medium` - French (France), female
- `de_DE-thorsten-medium` - German (Germany), male

Voice models are automatically downloaded on first use and cached locally.

## Testing

Run the test suite to verify service functionality:

```bash
# Test local service
python test_service.py

# Test remote service
python test_service.py http://your-service-url:9001
```

## Integration with Blindr

This service is designed to replace the embedded Piper client in the blindr Discord bot:

```python
# Old embedded usage (blindr bot)
from src.piper.client import text_to_speech
audio_data = await text_to_speech("Hello world")

# New HTTP service usage
import httpx
async with httpx.AsyncClient() as client:
    response = await client.post(
        "http://localhost:9001/tts",
        json={"text": "Hello world"}
    )
    audio_data = response.content
```

## Architecture

```
┌─────────────────┐    HTTP     ┌──────────────────┐
│  blindr Bot     │──────────── │  Piper Service   │
│                 │   POST /tts │  (Port 9001)     │
└─────────────────┘             └──────────────────┘
                                          │
                                          ▼
                                ┌──────────────────┐
                                │  Piper Models    │
                                │  (Cached/GPU)    │
                                └──────────────────┘
```

## Performance Notes

- Voice models are loaded once and cached in memory
- Audio generation runs in thread executors to avoid blocking
- Model files are large (10-50MB each) but downloaded only once
- GPU acceleration supported if available

## Error Handling

The service provides detailed error messages and HTTP status codes:

- `400` - Bad Request (invalid text, voice not found)
- `404` - Voice model not found in catalog  
- `500` - Internal server error (model load failure, synthesis error)

## Logging

Logs are written to both console and file (configurable location):

```
2024-01-01 12:00:00 - piper-service - INFO - Starting Piper TTS Service...
2024-01-01 12:00:01 - piper-service - INFO - Voice model loaded: en_US-lessac-medium
2024-01-01 12:00:05 - piper-service - INFO - TTS request: 'Hello world' using voice 'en_US-lessac-medium'
```

## Deployment

For production deployment:

1. Use a process manager (systemd, Docker)
2. Configure reverse proxy (nginx) for SSL/load balancing
3. Set appropriate resource limits
4. Monitor disk space for model storage
5. Configure log rotation

## Development

The service is built with:

- **FastAPI**: Modern Python web framework
- **Piper TTS**: High-quality neural text-to-speech
- **Uvicorn**: ASGI server for production
- **Pydantic**: Data validation and serialization

## Troubleshooting

### Service Won't Start
- Check port availability: `lsof -i :9001`  
- Verify Python dependencies: `pip install -r requirements.txt`
- Check configuration: `python -c "from config import ServiceConfig; print(ServiceConfig().to_dict())"`

### Voice Models Not Loading
- Ensure models directory has write permissions
- Check network connectivity for downloads
- Verify disk space availability
- Review logs for specific error messages

### Audio Generation Fails
- Validate input text length (max 10,000 chars)
- Try different voice models
- Check system resources (memory, CPU)
- Enable debug logging for detailed diagnostics