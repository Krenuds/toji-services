# Logging — Plan

Goal: unify piper and whisper service logs into `/home/travis/toji-services-src/logs/` on the host, with one rotated file per service plus `docker logs` for live tailing.

## Current state (verified 2026-05-10)

| Service | Python logger | Container file | On host |
|---|---|---|---|
| piper | stdout + `FileHandler` → `/app/logs/piper-service.log` | yes, ~380 KB, growing | only `/var/lib/docker/containers/<id>/...-json.log` (file inside container is trapped — no mount) |
| whisper | stdout only | empty `/app/logs/` | only `/var/lib/docker/containers/<id>/...-json.log` |

Both stdout streams also carry uvicorn access lines, so `docker logs` is currently spammed every 30s by the healthcheck `GET /health 200`.

The whisper compose file in source declares a `whisper_logs` named volume and a `logging:` driver block, but the live container has none of it — same drift problem we already fixed for piper. Step 2 reconciles whisper at the same time.

## Defaults

| Knob | Value | Why |
|---|---|---|
| Per-service file size cap | 10 MB | Big enough for hours of activity, small enough to grep |
| Rotated file count | 5 | ~50 MB total per service |
| Docker daemon log cap | 50 MB × 3 (`json-file`) | Independent backstop for `docker logs` |
| Health filter | drop `/health` from `uvicorn.access` only | Keeps real request logs, kills the 30s spam |
| Host log dir | `/home/travis/toji-services-src/logs/` | Already exists, already in `.gitignore` |

## Step 1 — Piper

**`piper-service/config.py` (`setup_logging`)**
- Replace `FileHandler` with `RotatingFileHandler(maxBytes=10_000_000, backupCount=5)`.
- Keep stdout `StreamHandler` and the existing formatter.
- Path stays `/app/logs/piper-service.log` (driven by `PIPER_LOG_FILE` env, already set in compose).

**`piper-service/service.py`** — after `logger = setup_logging(config)`:

```python
class _HealthFilter(logging.Filter):
    def filter(self, record):
        return "/health" not in record.getMessage()

logging.getLogger("uvicorn.access").addFilter(_HealthFilter())
```

**`piper-service/docker-compose.yml`**
- Add bind mount: `- ../logs:/app/logs`
- Add daemon log cap:
  ```yaml
  logging:
    driver: json-file
    options:
      max-size: "50m"
      max-file: "3"
  ```

**Verify**

```bash
cd piper-service && docker-compose up -d --build
ls -la ../logs/
tail -f ../logs/piper-service.log     # in another terminal, fire a TTS request
docker logs --tail 20 piper-service   # confirm no /health lines
```

Done when `logs/piper-service.log` exists on host with a real TTS request line, and `docker logs piper-service` is silent on `/health`.

### Step 1 — Outcome (2026-05-10) ✅

All four objectives met. WAV + Opus paths smoke-tested green. `/health` filtered.

**Surprise we hit and fixed:**
The bind mount source `/home/travis/services/data/piper/models` was **empty and root-owned** on the host. The previous container had been serving TTS for two days off stale cached state — recreating it exposed the divergence and broke model loading until we seeded the directory.

What "in sync with reality" actually meant:
1. `chown -R 1001:1001 /home/travis/services/data/piper` (container runs as UID 1001).
2. `docker cp piper-service:/opt/models/piper/. /home/travis/services/data/piper/models/` to seed the default voice from the image.
3. Restart — service then loaded `en_US-lessac-medium` from the bind mount on its own.

Going forward, the bind mount is the actual source of truth: add a voice by dropping the `.onnx` + `.onnx.json` pair into `/home/travis/services/data/piper/models/` (must be readable by UID 1001), no rebuild needed. The image still bakes the default voice as a fallback / first-boot seed at `/opt/models/piper/`.

## Step 2 — Whisper

Bigger because whisper has no file handler today and the source compose doesn't match the running container. We reconcile compose at the same time, same discipline as the 2026-04-25 piper reconcile.

**Pre-step (mandatory):** rewrite `whisper-service/docker-compose.yml` to match `docker inspect whisper-service` — mounts, env, command, GPU config, restart policy. Sanity check: `docker-compose up -d` with no rebuild should be a no-op against the live container before adding any new logging config.

**`whisper-service/logger.py` (`get_logger`)**
- Add `RotatingFileHandler(maxBytes=10_000_000, backupCount=5)` writing to `/app/logs/whisper-service.log`.
- Path overridable via `WHISPER_LOG_FILE` env (default `/app/logs/whisper-service.log`) for parity with piper.
- Keep existing stdout handler.

**`whisper-service/service.py`** — same `_HealthFilter` snippet on `uvicorn.access` as piper.

**`whisper-service/docker-compose.yml`**
- Add `WHISPER_LOG_FILE=/app/logs/whisper-service.log` env.
- Add bind mount: `- ../logs:/app/logs`
- Drop the `whisper_logs` named volume (declared but not actually mounted on the running container).
- Align the existing daemon log cap to `50m × 3` to match piper.
- Verify `read_only: true` and `/app/tmp` tmpfs against live container before applying.

**Verify**

```bash
cd whisper-service && docker-compose up -d --build
ls -la ../logs/
tail -f ../logs/whisper-service.log   # trigger a transcription
docker logs --tail 20 whisper-service # no /health lines
```

Done when both `logs/piper-service.log` and `logs/whisper-service.log` are growing on the host from a single `tail -f ../logs/*.log`, and neither `docker logs` is full of `/health` noise.

### Step 2 — Outcome (2026-05-10) ✅

All objectives met. End-to-end TTS→STT round-trip verified: piper synthesizes "the quick brown fox", whisper transcribes it back as `"The quick brown fox jumps over the lazy dog."`. GPU still live (RTX 2080, CUDA enabled). Both `logs/*.log` files growing live, `/health` filtered out of `docker logs`.

Whisper now compose-managed (was hand-launched before). Compose drift cleaned up — `read_only: true`, the `whisper_models` and `whisper_logs` named volumes, and unverified `mem_limit`/`cap_drop` fields all dropped to match the live container. GPU `deploy.resources` block preserved (verified live). Tmpfs `/app/tmp` preserved.

**Four surprises hit and fixed during rollout** — document so the next rebuild doesn't relearn them:

1. **`docker cp` bypasses bind mounts.** Whisper's model cache (464 MB) lived in a "ghost" bind mount — source dir on host had been deleted long ago, but the running container still saw the data via held inode. `docker cp container:/path` reads the underlying *image layer*, not the bind-mounted view, so it returned an empty directory. Workaround: stream via the container's view with tar:
   ```bash
   sudo docker exec --user 0 whisper-service tar -cf - -C /root/.cache/huggingface . \
     | sudo tar -xf - -C /home/travis/services/data/whisper/models/
   sudo chown -R 1001:1001 /home/travis/services/data/whisper/models
   ```

2. **Hand-launched container can't be recreated by compose.** The pre-existing whisper container was started ad hoc, so `docker-compose up -d` raised a name conflict. One-time fix: `docker stop whisper-service && docker rm whisper-service && docker-compose up -d`. From here on, compose owns the lifecycle.

3. **CUDA 13 dependency drift on fresh rebuild.** `requirements.txt` previously used only floor constraints (`torch>=2.1.0`). A fresh `pip install` in 2026-05 resolved `torch==2.11.0`, which switched to `nvidia-*-cu13` deps. `ctranslate2` (the faster-whisper backend) is built against CUDA 12 and crashed at runtime with `libcublas.so.12 not found`. Fix: pin to the known-working CUDA 12 stack:
   ```
   torch==2.8.0
   torchaudio==2.8.0
   faster-whisper==1.2.0
   ctranslate2==4.6.0
   ```

4. **`requests` no longer transitive in faster-whisper 1.2.** The Dockerfile's pre-download step (`python -c "from faster_whisper import WhisperModel; WhisperModel('small', ...)"`) imports `requests` indirectly. faster-whisper 1.2 dropped it as a dep. Added `requests>=2.31.0` to `requirements.txt`.

## Out of scope

- Removing other historical references to `whisper_logs` / `piper_logs` in unrelated files (handled in the broader cleanup pass).
- Centralized log shipping (journald, Loki, etc.) — overkill for two services on one box.
- Touching the bot side (`toji2`).
