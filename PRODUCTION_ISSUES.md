# Production Issues and Solutions

## Audio Processing Service Issues Resolved

This document captures critical production issues encountered with the Toji speech processing services and their solutions. **These fixes are already implemented in the current codebase.**

## Issue #1: Whisper Service GPU Crashes During Audio Processing

### Symptoms
- Service starts successfully and passes health checks
- GPU is detected and model loads without errors
- Service crashes with exit code 139 (segmentation fault) when processing actual audio
- Client receives "Server disconnected without sending a response" errors
- Container enters restart loop during audio transcription

### Root Cause
The cuDNN libraries required for GPU acceleration were installed via pip/PyTorch but not available in the system library search path (`LD_LIBRARY_PATH`). While the service could initialize and load models, CUDA operations during audio processing failed to find the required cuDNN symbols.

### Technical Details
- cuDNN libraries were present in `/opt/venv/lib/python3.11/site-packages/nvidia/cudnn/lib/`
- PyTorch could access them for basic operations
- faster-whisper library needed system-level access during intensive audio processing
- Missing library path caused segfaults during `cudnnCreateTensorDescriptor` calls

### Solution Applied
Updated `whisper-service/Dockerfile` to include cuDNN libraries in `LD_LIBRARY_PATH`:

```dockerfile
# Add cuDNN libraries to library path for GPU acceleration
ENV LD_LIBRARY_PATH="/opt/venv/lib/python3.11/site-packages/nvidia/cudnn/lib:/opt/venv/lib/python3.11/site-packages/ctranslate2.libs:${LD_LIBRARY_PATH}"
```

### Verification
```bash
# Test GPU detection
curl -s http://localhost:9000/health | grep cuda
# Should show: "device":"cuda"

# Test actual audio processing (not just health checks)
curl -X POST http://localhost:9000/asr \
  -F "audio_file=@test.wav" -F "output=txt"
# Should return transcription without service crash
```

---

## Issue #2: Piper Service TTS Generation Failures

### Symptoms
- Service starts successfully and passes health checks
- Voice models load correctly
- TTS requests return 500 errors: "TTS generation failed: # channels not specified"
- Later: "PiperVoice object has no attribute 'synthesize_wav'"

### Root Cause
Two-part issue:
1. WAV file creation without proper format parameters (channels, sample width, frame rate)
2. Incorrect Piper API method usage (using non-existent `synthesize_wav` instead of `synthesize`)

### Technical Details
- Python's `wave` module requires explicit format configuration when writing
- Piper API changed from earlier documentation/examples
- Audio generation failed at WAV file creation, not synthesis

### Solution Applied
Fixed `piper-service/service.py` synthesis function:

```python
def synthesize_audio_sync(text: str, voice_model: piper.PiperVoice) -> bytes:
    """Synchronous audio synthesis - runs in executor."""
    wav_buffer = io.BytesIO()
    
    try:
        with wave.open(wav_buffer, 'wb') as wav_file:
            # Configure WAV format parameters  
            wav_file.setnchannels(1)  # Mono audio
            wav_file.setsampwidth(2)  # 16-bit samples
            wav_file.setframerate(voice_model.config.sample_rate)  # Use model's sample rate
            
            # Use correct Piper API method
            voice_model.synthesize(text, wav_file)  # NOT synthesize_wav
        
        return wav_buffer.getvalue()
        
    finally:
        wav_buffer.close()
```

### Verification
```bash
# Test TTS generation
curl -X POST http://localhost:9001/tts \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, this is a test"}' --output test.wav

# Verify audio file was created
ls -la test.wav  # Should be >100KB, not an error message
```

---

## Production Deployment Checklist

### Pre-Deployment Verification
Before deploying these services, verify both fixes are working:

1. **Whisper GPU Processing Test**:
   ```bash
   # Health check shows CUDA
   curl -s http://localhost:9000/health | grep '"device":"cuda"'
   
   # Actual audio processing works
   curl -X POST http://localhost:9000/asr \
     -F "audio_file=@sample.wav" -F "output=txt"
   ```

2. **Piper TTS Generation Test**:
   ```bash
   # TTS generates valid audio
   curl -X POST http://localhost:9001/tts \
     -H "Content-Type: application/json" \
     -d '{"text": "Production test successful"}' --output production_test.wav
   
   # Verify file size
   wc -c production_test.wav  # Should be >50000 bytes
   ```

### Monitoring Commands
```bash
# Monitor service health
docker ps | grep -E "(whisper|piper)"

# Check for crashes/restarts
docker logs blindr-whisper --tail 20 | grep -E "(error|Error|exit|restart)"
docker logs blindr-piper --tail 20 | grep -E "(error|Error|exit|restart)"

# Monitor GPU usage during processing
nvidia-smi -l 1
```

### Known Working Configuration
- **Hardware**: NVIDIA GeForce RTX 2080 (8GB VRAM)
- **OS**: Ubuntu 22.04
- **Docker**: 24.0.5+ (NOT snap version)
- **Models**: Whisper `small`, Piper `en_US-lessac-medium`
- **Performance**: 6.9s audio transcribed in <1s, TTS generation <1s

## Future Deployment Notes

1. **Always test with actual audio/text**, not just health checks
2. **Monitor container restarts** - they indicate processing crashes
3. **cuDNN library path** is critical for GPU workloads in containers
4. **Piper API methods** may change between versions
5. **WAV format configuration** is required for audio generation

These issues are **resolved in the current codebase** but documented for future reference and troubleshooting.