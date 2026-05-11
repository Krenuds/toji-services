# whisper-service

`faster-whisper` wrapped in FastAPI. Audio in, transcript out. GPU-accelerated with CPU fallback. API-compatible with the public `whisper-asr-webservice` at `:9000/asr`.

## Container

- Built from `Dockerfile` (two-stage, Python 3.11 venv, non-root `whisper` uid 1001).
- Container name: `whisper-service`, image: `whisper-service:latest`.
- Port `9000` exposed.
- CUDA-12 stack **pinned**: `torch==2.8.0`, `torchaudio==2.8.0`, `faster-whisper==1.2.0`, `ctranslate2==4.6.0`. Drifting torch upward breaks ctranslate2 — don't.
- `LD_LIBRARY_PATH` set in the Dockerfile to point at bundled cuDNN + ctranslate2 libs.

## GPU vs CPU

Default GPU (RTX 2080, `float16`). Auto-fallback to CPU (`float32`, 4 threads) on any of:

1. No CUDA available.
2. CUDA probe failure during `__init__`.
3. GPU model-load exception.

The `DEVICE=cpu` env var (if set) is **not** consulted — device selection is per-probe.

## Endpoints

| Method | Path | Notes |
|---|---|---|
| POST | `/asr` | `task`, `language`, `initial_prompt`, `output=txt\|vtt\|srt\|tsv\|json`, `encode` (accepted, ignored). |
| POST | `/detect-language` | `{detected_language, language_probability}`. |
| GET | `/health` | `{status, device, model_size, gpu_available, gpu_name}`. Filtered from access log. |
| GET | `/` | Service banner. |
| GET | `/docs` | FastAPI Swagger UI. |

**Caveats:** `output=tsv` is in the Literal but has no handler — falls through to plain text. The `encode` flag is legacy API-compat ballast. Content-type validation currently rejects `.webm`, `.opus`, `.aac` even though faster-whisper can decode them. See repo `ROADMAP.md`.

## Config (env vars)

| Var | Default | Notes |
|---|---|---|
| `WHISPER_HOST` | `0.0.0.0` | |
| `WHISPER_PORT` | `9000` | |
| `WHISPER_MODEL_SIZE` | `small` | `tiny` \| `base` \| `small` \| `medium` \| `large-v2` \| `large-v3`. |
| `WHISPER_LOG_FILE` | `/app/logs/whisper-service.log` | Set in compose. |
| `LOG_LEVEL` | `INFO` | |
| `CUDA_VISIBLE_DEVICES` | `0` | |

`WhisperConfig` knobs in `config.py` (`beam_size`, `temperature`, `no_speech_threshold`, `condition_on_previous_text`) are **not** env-driven — edit `config.py` and rebuild.

## Model story

- Default `small`. Image bakes `small` at build time. Override via `WHISPER_MODEL_SIZE`.
- Host cache: `~/services/data/whisper/models` bind-mounted to `/root/.cache/huggingface` (HF directory layout, uid 1001).
- If the host cache directory is empty after restart, **re-seed via `tar`** through a running container, not `docker cp` — `docker cp` reads from the image layer, not the bind-mounted view.

## Build / run

```bash
cd whisper-service
docker compose up -d --build
curl -s localhost:9000/health | jq
docker compose logs -f
tail -f ../logs/whisper-service.log
```

## Troubleshooting

- `libcublas.so.12 not found`: CUDA-13 wheel drift. Rebuild with the pinned set.
- CPU mode when GPU expected: check `nvidia-smi` and the `deploy.resources` block in `docker-compose.yml`.
- Empty model dir after restart: re-seed via `tar` (see above), not `docker cp`.
- Healthcheck unhealthy but service responds: ensure `curl` is installed in the runtime stage.
- `large-v3` OOM: 8 GB VRAM on a 2080 is tight with other CUDA consumers. Fall back to `medium`.
- `/health` log spam: confirm `_HealthFilter` is still attached after any uvicorn upgrade.
- Log file size cap: 10 MB × 5 ≈ 50 MB on host.

## Known cruft (deferred — see repo `ROADMAP.md`)

- Dead `tsv` output path, dead `encode` parameter.
- Content-type allowlist too restrictive.
- `WhisperConfig` knobs hardcoded next to env-driven knobs — inconsistent.
- Duplicate device-selection logic between `__init__` and `_load_model` CPU fallback.
