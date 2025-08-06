# Migration Plan: Extracting Services from blindr

## Objective
Extract Whisper (STT) and Piper (TTS) services from the blindr monolithic codebase into standalone Docker containers while maintaining zero downtime and full backward compatibility.

## Current State Analysis

### Whisper Service
- **Location**: `/home/travis/blindr/src/whisper/service.py`
- **Type**: Already a FastAPI service
- **Dependencies**: 
  - Custom logger from blindr
  - Config settings from blindr
  - Environment variables
- **Complexity**: LOW - Mostly standalone

### Piper Service  
- **Location**: `/home/travis/blindr/src/piper/client.py`
- **Type**: Embedded library (not a service)
- **Dependencies**:
  - Direct library calls
  - Async/await patterns
  - Shared memory model
- **Complexity**: HIGH - Needs service wrapper

## Migration Steps

### Step 1: Prepare Whisper Service (Day 1)
- [ ] Copy `service.py` to `/home/travis/services/whisper-service/`
- [ ] Remove blindr-specific imports:
  - [ ] Replace custom logger with standard logging
  - [ ] Replace config with environment variables
  - [ ] Remove `src.` prefix from imports
- [ ] Create minimal `requirements.txt`:
  ```
  fastapi==0.104.0
  uvicorn[standard]==0.24.0
  faster-whisper==0.10.0
  torch>=2.0.0
  python-multipart==0.0.6
  python-dotenv==1.0.0
  ```
- [ ] Test standalone operation

### Step 2: Create Piper Service (Day 1-2)
- [ ] Design HTTP API matching Whisper pattern:
  ```python
  POST /tts
  {
    "text": "Hello world",
    "voice": "en_US-lessac-medium",
    "speed": 1.0
  }
  Returns: WAV audio stream
  ```
- [ ] Create `service.py` wrapper around piper library
- [ ] Implement model caching and management
- [ ] Add health check endpoint
- [ ] Test audio generation

### Step 3: Dockerize Services (Day 2)
- [ ] Create Whisper Dockerfile:
  - [ ] CUDA base image
  - [ ] Python dependencies
  - [ ] Model downloads
  - [ ] Health check
- [ ] Create Piper Dockerfile:
  - [ ] CUDA base image
  - [ ] Piper installation
  - [ ] Voice model setup
  - [ ] Health check
- [ ] Test GPU detection and fallback

### Step 4: Docker Compose Setup (Day 2)
- [ ] Create `docker-compose.yml`:
  - [ ] Service definitions
  - [ ] GPU resource allocation
  - [ ] Volume mounts for models
  - [ ] Network configuration
  - [ ] Environment variables
- [ ] Test service orchestration
- [ ] Verify inter-service communication

### Step 5: Update blindr Bot (Day 3)
- [ ] Create HTTP clients for services:
  - [ ] Whisper client with retry logic
  - [ ] Piper client with streaming support
- [ ] Add configuration for service URLs
- [ ] Implement fallback for service failures
- [ ] Update environment variables

### Step 6: Integration Testing (Day 3)
- [ ] Test with Docker services running
- [ ] Verify audio pipeline end-to-end
- [ ] Performance benchmarking
- [ ] Load testing
- [ ] Error scenario testing

### Step 7: Deployment (Day 4)
- [ ] Create systemd service files
- [ ] Set up auto-start on boot
- [ ] Configure log rotation
- [ ] Update blindr deployment docs
- [ ] Switch production to Docker services

## Rollback Plan

If issues arise during migration:

1. **Immediate Rollback** (< 5 minutes)
   - Stop Docker services
   - Restart blindr with embedded services
   - No code changes required

2. **Partial Rollback**
   - Keep Whisper dockerized (low risk)
   - Revert Piper to embedded (higher risk)

3. **Feature Flags**
   ```python
   USE_DOCKER_WHISPER = os.getenv("USE_DOCKER_WHISPER", "false") == "true"
   USE_DOCKER_PIPER = os.getenv("USE_DOCKER_PIPER", "false") == "true"
   ```

## Testing Checklist

### Functional Tests
- [ ] Audio transcription accuracy
- [ ] TTS voice quality
- [ ] Language detection
- [ ] Multiple audio formats
- [ ] Long text handling
- [ ] Unicode/emoji support

### Performance Tests
- [ ] Response time < baseline
- [ ] Memory usage stable
- [ ] GPU utilization efficient
- [ ] Concurrent request handling
- [ ] Service recovery time

### Integration Tests
- [ ] Bot connects to services
- [ ] Error handling works
- [ ] Retry logic functions
- [ ] Health checks pass
- [ ] Graceful degradation

## Success Criteria

- ✅ Both services running in Docker
- ✅ blindr bot fully functional
- ✅ No increase in latency
- ✅ GPU memory usage optimized
- ✅ Services auto-restart on failure
- ✅ Logs properly collected
- ✅ Documentation updated

## Risk Assessment

### High Risk
- **Piper service creation**: New code, potential bugs
- **GPU memory**: Both services competing for VRAM

### Medium Risk  
- **Network latency**: HTTP overhead vs direct calls
- **Model loading**: Startup time increased

### Low Risk
- **Whisper extraction**: Already a service
- **Docker setup**: Well-understood technology

## Timeline

- **Day 1**: Extract and prepare services
- **Day 2**: Dockerize and compose
- **Day 3**: Integration and testing
- **Day 4**: Deployment and monitoring

Total: 4 days with buffer for issues

## Post-Migration Tasks

1. **Monitoring Setup**
   - Prometheus metrics
   - Grafana dashboards
   - Alert rules

2. **Performance Optimization**
   - Request batching
   - Response caching
   - Model optimization

3. **Documentation**
   - API documentation
   - Deployment guide
   - Troubleshooting guide

## Notes

- Keep blindr bot changes minimal initially
- Maintain backward compatibility
- Document all API contracts
- Test thoroughly before production
- Have rollback ready at each step