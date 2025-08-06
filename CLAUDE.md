# Blindr Services - Dockerized Components

## Project Overview
This directory contains the extracted and dockerized services from the **blindr** voice assistant project. These services were originally embedded within the main blindr codebase at `/home/travis/blindr/` and are being separated to improve architecture, scalability, and maintainability.

## Parent Project: blindr
- **Location**: `/home/travis/blindr/`
- **Purpose**: Discord voice assistant for visually impaired users
- **Status**: Working prototype with embedded services
- **Why Extraction**: The main bot became too monolithic; services need independent scaling

## Services Being Extracted

### 1. Whisper Service (Speech-to-Text)
- **Original Location**: `/home/travis/blindr/src/whisper/service.py`
- **Purpose**: GPU-accelerated speech recognition using faster-whisper
- **Port**: 9000
- **Status**: Already a FastAPI service, needs minor adjustments for standalone operation

### 2. Piper Service (Text-to-Speech)
- **Original Location**: `/home/travis/blindr/src/piper/client.py` (embedded library)
- **Purpose**: Natural voice synthesis using Piper TTS
- **Port**: 9001 (new)
- **Status**: Currently embedded library, needs conversion to HTTP service

## Architecture Relationship
```
[Discord Users] <-> [blindr Bot @ /home/travis/blindr/]
                            |
                            v
                    [HTTP API Calls]
                    /               \
                   v                 v
        [Whisper Service]    [Piper Service]
         (Port 9000)          (Port 9001)
```

## Migration Goals
1. **Zero Downtime**: Services should be swappable without breaking the bot
2. **Backward Compatible**: Initial versions maintain same API contracts
3. **GPU Optimization**: Both services share GPU resources efficiently
4. **System Services**: Run as Docker containers managed by systemd

## Directory Structure
```
/home/travis/services/
├── CLAUDE.md (this file)
├── README.md (user documentation)
├── docker-compose.yml (orchestration)
├── whisper-service/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── service.py
│   └── config/
└── piper-service/
    ├── Dockerfile
    ├── requirements.txt
    ├── service.py
    ├── models/ (cached models)
    └── config/
```

## Development Workflow
1. Extract service code from blindr project
2. Remove blindr-specific dependencies
3. Create standalone Docker containers
4. Test with blindr bot
5. Deploy as system services

## Important Notes
- Services must remain compatible with blindr bot's current expectations
- GPU memory is shared - implement proper cleanup on shutdown
- Model files are large - use Docker volumes for persistence
- Both services should auto-restart on failure

## Environment Variables
Services inherit configuration from blindr where applicable:
- `WHISPER_PORT`: 9000 (default)
- `PIPER_PORT`: 9001 (new)
- `CUDA_VISIBLE_DEVICES`: GPU selection
- `LOG_LEVEL`: info/debug/error

## Testing Integration
After dockerizing, test with blindr bot:
```bash
# From blindr directory
cd /home/travis/blindr
./blindr start  # Should connect to dockerized services
```

## Status Tracking
- [ ] Whisper service extracted
- [ ] Whisper Dockerfile created
- [ ] Piper service created (convert from library)
- [ ] Piper Dockerfile created
- [ ] Docker Compose configuration
- [ ] Integration tested with blindr
- [ ] Systemd service files created
- [ ] Documentation updated in both projects

## Cross-Project Communication
- Changes here may require updates in `/home/travis/blindr/`
- Service APIs must maintain backward compatibility
- Breaking changes require coordinated updates

This separation allows the blindr bot to focus on Discord interaction and conversation management while these services handle the heavy lifting of speech processing.