# earpiece

Two self-contained Docker microservices for voice I/O — speech in, speech out. Plain HTTP APIs you can drop into any project that needs to hear or speak.

| Service | Does | Port | Hardware |
|---|---|---|---|
| `piper-service` | Text → speech audio (WAV / Ogg-Opus) | 9001 | CPU |
| `whisper-service` | Speech audio → text (txt / json / srt / vtt) | 9000 | NVIDIA GPU, CPU fallback |

Each service is independent. You can run one without the other.

## Requirements

- Docker + Docker Compose v2
- For `whisper-service` on GPU: NVIDIA driver + [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html). Without it, the service auto-falls back to CPU.
- Host directories for model caches (the composes bind-mount these):
  - `~/services/data/piper/models`
  - `~/services/data/whisper/models`

```bash
mkdir -p ~/services/data/piper/models ~/services/data/whisper/models
```

## Quickstart

Each service is launched from its own directory. There is no root compose.

```bash
# TTS
cd piper-service
docker compose up -d --build

# STT (separate terminal or after)
cd ../whisper-service
docker compose up -d --build
```

First build pulls models and takes a few minutes. After that the containers come back automatically across reboots (`restart: unless-stopped`).

Verify:

```bash
curl -s localhost:9001/health   # piper
curl -s localhost:9000/health   # whisper
```

## Using the APIs

Both services speak plain HTTP. POST a request, get a response back. No streaming, no sockets, no state between calls.

### Piper — text to audio

```bash
# Default WAV
curl -X POST localhost:9001/tts \
  -H 'content-type: application/json' \
  -d '{"text": "hello world"}' \
  --output hello.wav

# Ogg-Opus (48 kHz stereo, voice-friendly)
curl -X POST localhost:9001/tts \
  -H 'content-type: application/json' \
  -d '{"text": "hello world", "format": "opus"}' \
  --output hello.ogg

# Pick a voice
curl -X POST localhost:9001/tts \
  -H 'content-type: application/json' \
  -d '{"text": "bonjour", "voice": "fr_FR-siwis-medium"}' \
  --output bonjour.wav
```

Other endpoints:

- `GET /voices` — list installed and available voices
- `POST /download-voice` — pull a new voice model from Hugging Face
- `GET /docs` — interactive Swagger UI

### Whisper — audio to text

`/asr` takes a multipart file upload. The `output` query param picks the format.

```bash
# Plain text
curl -X POST 'localhost:9000/asr?output=txt' \
  -F audio_file=@recording.wav

# JSON with timestamps
curl -X POST 'localhost:9000/asr?output=json' \
  -F audio_file=@recording.wav

# Subtitles
curl -X POST 'localhost:9000/asr?output=srt' \
  -F audio_file=@recording.wav

# Force a language and add a hint
curl -X POST 'localhost:9000/asr?output=txt&language=en' \
  -F audio_file=@recording.wav \
  -F 'initial_prompt=technical discussion about Docker'

# Just detect the language
curl -X POST localhost:9000/detect-language \
  -F audio_file=@recording.wav
```

`GET /docs` has the full interactive reference.

## Configuration

Both composes ship with sensible defaults baked in as environment variables. To change them, edit the `environment:` block in the relevant `docker-compose.yml` and run `docker compose up -d` again.

Most-touched knobs:

| Service | Var | Default | What it does |
|---|---|---|---|
| piper | `PIPER_DEFAULT_VOICE` | `en_US-lessac-medium` | Voice pre-loaded at startup |
| piper | `PIPER_MAX_TEXT_LENGTH` | `10000` | Max characters per `/tts` request |
| whisper | `WHISPER_MODEL_SIZE` | `small` | `tiny`, `base`, `small`, `medium`, `large-v2`, `large-v3` |
| whisper | `CUDA_VISIBLE_DEVICES` | `0` | Which GPU to use |
| both | `LOG_LEVEL` | `INFO` | `DEBUG`, `INFO`, `WARNING`, `ERROR` |

See each service's `CLAUDE.md` for the full list.

## Operations

```bash
# Restart a service
cd piper-service && docker compose restart

# Rebuild after source changes
cd piper-service && docker compose up -d --build

# Stop until you start it again (survives reboots)
cd piper-service && docker compose stop

# Tail logs (host-side, both services share ./logs/)
tail -f logs/piper-service.log logs/whisper-service.log

# Tail Docker stdout
cd piper-service && docker compose logs -f
```

Logs rotate at 10 MB × 5 files per service. Docker container logs cap at 50 MB × 3.

## Layout

```
earpiece/
├── piper-service/         # TTS — see piper-service/CLAUDE.md
├── whisper-service/       # STT — see whisper-service/CLAUDE.md
├── logs/                  # Bind-mounted into both containers
└── CLAUDE.md              # Repo-level notes
```

Per-service `CLAUDE.md` files document the internals, troubleshooting, and known quirks.
