# Next Steps for Service Extraction

## Immediate Actions Required

### 1. Extract Whisper Service
The Whisper service is the easiest to extract since it's already a FastAPI service.

**Commands to run:**
```bash
# Copy the service file
cp /home/travis/blindr/src/whisper/service.py /home/travis/services/whisper-service/

# Copy config if needed
cp /home/travis/blindr/config/whisper_config.json /home/travis/services/whisper-service/config/
```

**Code changes needed in service.py:**
- Remove `from src.config import get_settings`
- Remove `from src.logger import get_logger`
- Replace with standard Python logging
- Update imports to be standalone

### 2. Create Piper Service
Piper needs to be converted from a library to an HTTP service.

**New file to create:** `/home/travis/services/piper-service/service.py`

**Key endpoints needed:**
- `POST /tts` - Generate speech from text
- `GET /voices` - List available voices
- `GET /health` - Health check
- `POST /download-voice` - Download new voice model

### 3. Create Docker Infrastructure

**Files to create:**
- `/home/travis/services/docker-compose.yml`
- `/home/travis/services/whisper-service/Dockerfile`
- `/home/travis/services/whisper-service/requirements.txt`
- `/home/travis/services/piper-service/Dockerfile`
- `/home/travis/services/piper-service/requirements.txt`

### 4. Update blindr Bot

**Files to modify in /home/travis/blindr/:**
- `src/piper/client.py` - Convert to HTTP client
- `src/config/settings.py` - Add service URLs
- `.env` - Add service endpoints

**New environment variables:**
```
WHISPER_SERVICE_URL=http://localhost:9000
PIPER_SERVICE_URL=http://localhost:9001
USE_DOCKER_SERVICES=true
```

## Testing Plan

### Local Testing (Before Docker)
1. Run extracted Whisper service standalone
2. Test Piper service with curl commands
3. Verify model downloads work

### Docker Testing
1. Build images locally
2. Run with docker-compose
3. Test GPU detection
4. Verify model persistence

### Integration Testing
1. Start Docker services
2. Run blindr bot
3. Test voice commands
4. Monitor resource usage

## Questions to Resolve

1. **Model Storage**: Should models be in Docker images or mounted volumes?
   - Recommendation: Volumes for flexibility

2. **Service Discovery**: Hard-coded URLs or service discovery?
   - Recommendation: Environment variables initially

3. **Authentication**: Add API keys to services?
   - Recommendation: Not initially, add later

4. **Logging**: Centralized or per-service?
   - Recommendation: Per-service initially, centralize later

## File Structure Created

```
/home/travis/services/
├── CLAUDE.md              ✅ Created - Project context
├── README.md              ✅ Created - User documentation  
├── NEXT_STEPS.md          ✅ Created - This file
├── .gitignore             ✅ Created - Git ignore rules
├── docs/
│   ├── ARCHITECTURE.md   ✅ Created - Technical details
│   └── MIGRATION_PLAN.md ✅ Created - Step-by-step plan
├── whisper-service/       📁 Ready for code
│   └── (empty)
└── piper-service/         📁 Ready for code
    └── (empty)
```

## Commands to Start Migration

```bash
# 1. Navigate to services directory
cd /home/travis/services

# 2. Start extracting Whisper
cp /home/travis/blindr/src/whisper/service.py whisper-service/

# 3. Create requirements for Whisper
echo "fastapi>=0.104.0
uvicorn[standard]>=0.24.0
faster-whisper>=0.10.0
torch>=2.0.0
python-multipart>=0.0.6
python-dotenv>=1.0.0" > whisper-service/requirements.txt

# 4. Test Whisper standalone (after code cleanup)
cd whisper-service
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python service.py
```

## Progress Tracking

- [x] Created directory structure
- [x] Added documentation files
- [x] Created CLAUDE.md for context
- [ ] Extract Whisper service code
- [ ] Clean up Whisper dependencies
- [ ] Create Piper HTTP service
- [ ] Write Dockerfiles
- [ ] Create docker-compose.yml
- [ ] Update blindr to use HTTP clients
- [ ] Test integration
- [ ] Deploy as system services

## Report Summary

✅ **Completed Setup:**
- Created `/home/travis/services/` directory structure
- Added comprehensive documentation:
  - `CLAUDE.md` - Explains the relationship between projects
  - `README.md` - User-facing documentation
  - `docs/ARCHITECTURE.md` - Technical architecture details
  - `docs/MIGRATION_PLAN.md` - Step-by-step migration plan
  - `NEXT_STEPS.md` - Immediate action items
- Set up project structure for both services
- Prepared for Docker containerization

The new services project is now aware that it's a extraction from the blindr project and has clear documentation about the migration goals and process. The folder structure is ready for the next phase of actually extracting and dockerizing the services.