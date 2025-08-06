# Services Architecture

## Overview

This document describes the technical architecture of the blindr speech processing services, their relationship to the main blindr bot, and the rationale behind the service extraction.

## Background

Originally, the speech processing components (Whisper STT and Piper TTS) were tightly integrated within the blindr Discord bot codebase. This monolithic approach led to several challenges:

1. **Resource Contention**: The bot process competed with ML models for memory and GPU
2. **Scaling Issues**: Cannot scale STT/TTS independently from the bot
3. **Development Friction**: Changes to services required full bot restarts
4. **Reusability**: Other projects couldn't leverage these services

## Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Discord Users                         │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                    blindr Bot Process                        │
│                  (/home/travis/blindr/)                      │
│                                                              │
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────────┐ │
│  │   Discord    │  │    Claude     │  │   Conversation  │ │
│  │  Connection  │  │  Integration  │  │   Management    │ │
│  └──────────────┘  └───────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                    │                            │
                    ▼                            ▼
         ┌──────────────────┐         ┌──────────────────┐
         │  Whisper Service │         │  Piper Service   │
         │   (Port 9000)    │         │   (Port 9001)    │
         │                  │         │                  │
         │  ┌────────────┐  │         │  ┌────────────┐  │
         │  │  FastAPI   │  │         │  │  FastAPI   │  │
         │  └────────────┘  │         │  └────────────┘  │
         │  ┌────────────┐  │         │  ┌────────────┐  │
         │  │   Model    │  │         │  │   Model    │  │
         │  │  Manager   │  │         │  │  Manager   │  │
         │  └────────────┘  │         │  └────────────┘  │
         │  ┌────────────┐  │         │  ┌────────────┐  │
         │  │    GPU     │  │         │  │    GPU     │  │
         │  │  Runtime   │  │         │  │  Runtime   │  │
         │  └────────────┘  │         │  └────────────┘  │
         └──────────────────┘         └──────────────────┘
                    │                            │
                    └────────────┬───────────────┘
                                 ▼
                        ┌─────────────────┐
                        │   NVIDIA GPU    │
                        │  (Shared VRAM)  │
                        └─────────────────┘
```

## Service Responsibilities

### Whisper Service (STT)
- **Input**: Audio files (WAV, MP3, etc.)
- **Processing**: Speech recognition using Whisper models
- **Output**: Transcribed text in various formats
- **State**: Stateless (each request independent)

### Piper Service (TTS)
- **Input**: Text strings
- **Processing**: Neural voice synthesis
- **Output**: WAV audio streams
- **State**: Model cached in memory

### blindr Bot
- **Discord Integration**: Voice channel management
- **Audio Pipeline**: Capture → STT → Process → TTS → Playback
- **Conversation State**: User context and history
- **Command Processing**: Slash commands and voice commands

## Communication Patterns

### Request Flow
1. User speaks in Discord voice channel
2. Bot captures audio stream
3. Bot sends audio to Whisper service (HTTP POST)
4. Whisper returns transcribed text
5. Bot processes text with Claude
6. Bot sends response to Piper service (HTTP POST)
7. Piper returns audio stream
8. Bot plays audio in voice channel

### Error Handling
- Services implement retry logic with exponential backoff
- Bot maintains fallback text responses if TTS fails
- Health checks prevent requests to unhealthy services

## Docker Architecture

### Base Images
- **Whisper**: `nvidia/cuda:11.8-runtime-ubuntu22.04`
- **Piper**: `nvidia/cuda:11.8-runtime-ubuntu22.04`

### Multi-Stage Builds
```dockerfile
# Stage 1: Builder
FROM python:3.10-slim as builder
# Install build dependencies
# Download models

# Stage 2: Runtime
FROM nvidia/cuda:11.8-runtime-ubuntu22.04
# Copy only necessary files
# Minimal runtime dependencies
```

### Resource Management
- **GPU Sharing**: Both services use same GPU via time-slicing
- **Memory Limits**: Docker memory constraints prevent OOM
- **Model Caching**: Volumes persist downloaded models

## Deployment Considerations

### Development
- Hot reload enabled for rapid iteration
- Debug logging for troubleshooting
- CPU mode for non-GPU development

### Production
- Health checks and auto-restart
- Log rotation and monitoring
- Resource limits and quotas

## Future Enhancements

### Planned Improvements
1. **Model Switching**: Dynamic model selection based on language/quality
2. **Batch Processing**: Queue and batch similar requests
3. **Caching Layer**: Redis cache for common phrases
4. **Load Balancing**: Multiple service instances
5. **Metrics Collection**: Prometheus/Grafana monitoring

### Potential Integrations
- WebSocket support for streaming
- gRPC for lower latency
- Message queue integration (RabbitMQ/Kafka)
- Kubernetes deployment manifests

## Migration Path

### Phase 1: Extraction (Current)
- [x] Create service directory structure
- [ ] Extract Whisper service code
- [ ] Create Piper HTTP service
- [ ] Write Dockerfiles

### Phase 2: Integration
- [ ] Update blindr bot to use HTTP clients
- [ ] Add retry and circuit breaker logic
- [ ] Implement health monitoring
- [ ] Performance testing

### Phase 3: Optimization
- [ ] GPU memory optimization
- [ ] Request batching
- [ ] Response caching
- [ ] Horizontal scaling

## Performance Considerations

### Latency Targets
- Whisper STT: < 500ms for 5s audio
- Piper TTS: < 200ms for average sentence
- End-to-end: < 2s for simple responses

### Throughput
- Whisper: 10+ concurrent requests
- Piper: 20+ concurrent requests
- Bottleneck: GPU memory (model size dependent)

### Resource Usage
- Whisper: ~2GB VRAM (small model)
- Piper: ~1GB VRAM
- CPU: 2-4 cores per service
- RAM: 4GB per service

## Security Considerations

### Network Security
- Services bind to localhost only in production
- TLS termination at reverse proxy
- API key authentication planned

### Input Validation
- File size limits
- Audio format validation
- Text length restrictions
- Rate limiting per client

### Model Security
- Models stored in read-only volumes
- No dynamic model downloads in production
- Checksum verification for model files