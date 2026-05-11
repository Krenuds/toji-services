# toji-services-src — Roadmap

Output of the Nelson "Documentation & Dead-Code Sweep" mission, 2026-05-10. This document is the runway for the next mission, which writes the three CLAUDE.md files for real.

> **Status (2026-05-10 — after mission #2):** §6 decisions and safe §4 smells **APPLIED**. See §9 at the bottom for the completion summary. Repo is ready for the CLAUDE.md writing mission.

---

## 1. What this repo actually is (corrected snapshot)

Two Docker microservices that back the Toji Discord bot (which lives outside this repo at `~/toji` and `/opt/Toji3`):

| Service | Role | Port | Hardware | Live lifecycle |
|---|---|---|---|---|
| `piper-service` | TTS (text → WAV/Ogg-Opus) | 9001 | CPU-only | `piper-service/docker-compose.yml` |
| `whisper-service` | STT (audio → text/srt/vtt/json) | 9000 | NVIDIA GPU w/ CPU fallback | `whisper-service/docker-compose.yml` |

**Critical correction discovered during recon:** the running containers are launched by the **per-service** compose files, NOT the root `docker-compose.yml` / `docker-compose.cpu.yml`. The root composes are stale legacy from the old `blindr-services` rename (commit `f4f1fe2`) — they still reference `blindr-whisper` / `blindr-piper` container names. See decision #1 below.

---

## 2. Dead code removed this mission (staged, not committed)

10 files deleted + 2 files edited. All rollbackable via `git restore`.

### Root
- `LOGGER.md` (deprecated, user-confirmed; implementation already landed in commits `0fe686e` + `7825710`)
- `.env.example` — 5 dead keys trimmed: `WHISPER_WORKERS`, `PIPER_WORKERS`, `DEBUG_MODE`, `ENABLE_API_LOGGING`, `ENABLE_METRICS` (no code reads them)
- `docs/` empty dir removed

### piper-service
- `build.sh` (only callers were also-deleted Makefile + DEPLOYMENT.md)
- `DEPLOYMENT.md` (stale — referenced deleted siblings; wrong consumer name "Blindr"; wrong systemd path)
- `entrypoint.sh` (184-line script, **not COPYed by Dockerfile, no `ENTRYPOINT` directive — pure orphan**)
- `Makefile` (targets either duplicated `docker compose` calls or invoked dead files)
- `piper-tts.service` (systemd unit; confirmed NOT installed on host; references nonexistent image tag and path)
- `start.py` (46-line uvicorn wrapper; COPYed into image but never executed — `CMD ["python", "service.py"]` runs the FastAPI app directly)
- `Dockerfile` — removed the dangling `COPY start.py` line

### whisper-service
- `build.sh` (wrapper around `docker build`; compose builds the image itself; zero references)

### Validation evidence
- `docker compose config -q` exits 0 on both root composes and the per-service composes.
- Running containers `piper-service` and `whisper-service` remain healthy throughout (no rebuilds triggered).
- Full rollback: `git restore --staged --worktree .`

---

## 3. Dead code FOUND but NOT touched (needs your call)

### 3a. The "ffmpeg paradox" in piper-service
- `piper-service/Dockerfile:51` installs `ffmpeg` as a system package.
- **Zero Python code uses ffmpeg.** No imports, no `subprocess`, no shell calls.
- The actual audio work (WAV → Opus) is done by **PyAV** (`av==17.0.1`) at `service.py:164-181`.
- **Recommendation:** delete the `ffmpeg` line from the Dockerfile. Shaves ~50MB from the image. Rebuild + smoke-test `/tts` with `format=opus` after.

### 3b. piper-service/test_service.py
- 192 lines of integration-style tests.
- Not container-shipped (`.dockerignore` excludes `test_*.py`).
- Only invoker was the deleted Makefile.
- Uses `requests`, which is not in `requirements.txt` — so it can't even run from the project venv as-is.
- **Recommendation:** delete it, OR resurrect properly by moving it under `piper-service/tests/`, adding `requests` to a dev-requirements file, and wiring a single make target. Status quo (file present but broken) is the worst option.

### 3c. Root docker-compose.yml + docker-compose.cpu.yml
- Stale `blindr-*` container names and volume bindings (`./data/whisper/models` vs the live `~/services/data/whisper/models`).
- Default voice in cpu.yml is `en_US-lessac-medium` while live container default is also `en_US-lessac-medium` — the GPU compose disagrees with itself (`en_US-amy-medium`). One of these is wrong.
- They include `nginx-proxy` + `prometheus` services under optional profiles that you almost certainly never run (host Nginx does the real proxying per your global CLAUDE.md).
- **Three options:**
  1. **Delete both root composes** (and `nginx/`, `monitoring/`) — per-service composes are the truth.
  2. **Keep them, rewrite to match live state**, document that root compose = "bring everything up at once" superset.
  3. **Keep CPU variant only** (it's actually useful as a doc of how to run without GPU) and delete the GPU variant which just duplicates the per-service file.

### 3d. nginx/ and monitoring/
- `nginx/nginx.conf` (7.7KB) and `monitoring/prometheus.yml` (2.7KB) exist only as targets of the optional profiles in the root compose. If we kill 3c option 1, these go too.
- **Recommendation:** delete unless you actually plan to use them.

### 3e. Commented-out `*_API_KEY` placeholders in `.env.example`
- Lines for OpenAI/Anthropic/ElevenLabs/etc. that don't apply to these services.
- **Recommendation:** delete.

---

## 4. service.py code smells (no fix this mission, listed for next pass)

### piper-service/service.py
1. Unused `import json` (line 16).
2. `PIPER_MAX_TEXT_LENGTH` env var is loaded into config but ignored — actual cap is hardcoded `max_length=10000` in the Pydantic model.
3. `PIPER_MAX_CONCURRENT` loaded and validated but never read — no concurrency limiter exists.
4. `PIPER_MODEL_CACHE_SIZE` loaded but unused — `voice_models` dict grows without eviction.
5. Deprecated `@app.on_event("startup"/"shutdown")` (FastAPI ≥0.93 wants `lifespan`).
6. `asyncio.get_event_loop()` inside coroutines (should be `get_running_loop()`).
7. `/download-voice` schedules background work that can `raise HTTPException` — exception silently swallowed by BackgroundTask runner.

### whisper-service/service.py
1. `encode: bool` Query param on `/asr` and `/detect-language` is accepted but never read (legacy whisper-asr-webservice API compat).
2. `output="tsv"` in the `Literal` has no handler — silently falls through to text.
3. Content-type validation rejects `.webm`, `.opus`, `.aac` despite faster-whisper handling them.
4. `WhisperConfig` knobs (`beam_size`, `temperature`, `no_speech_threshold`, `condition_on_previous_text`) are hardcoded — no env override despite being in pydantic Settings.
5. `best_of=5`, `compression_ratio_threshold=2.4`, `log_prob_threshold=-1.0` hardcoded next to env-driven knobs — inconsistent.
6. Deprecated `@app.on_event("shutdown")`.
7. `WHISPER_LOG_FILE` is set in compose but missing from `.env.example`.
8. Minor: duplicate device-selection logic between `__init__` and `_load_model` CPU fallback.

None of these are bugs that affect the user-facing service today. They're architectural cruft from the iteration history.

---

## 5. CLAUDE.md outlines for the next mission

Each service has a detailed outline drafted by its captain. The next mission expands these into prose. Stored in the mission directory:

- Root outline: `.nelson/findings-argyll.md` (§ at end)
- piper-service outline: inline in `.nelson/findings-kent.md` (or Kent's report)
- whisper-service outline: inline in Lancaster's report

### Root CLAUDE.md — section list to cover
1. Project purpose (what this repo is, what it isn't — the bot lives elsewhere)
2. Service map table (the table from §1 of this roadmap)
3. **Canonical lifecycle:** "use the per-service composes, not the root composes"
4. Shared directories (`logs/` host bind, `~/services/data/*` host bind for models)
5. Env vars used at the root level (just the bind path overrides)
6. How to bring everything up / restart / tail logs
7. Where the consumer lives (links to `~/toji`, `/opt/Toji3`)
8. Open work (link this roadmap)

### piper-service/CLAUDE.md — sections (Kent's outline)
Purpose · Container layout · Endpoints/API · Config env vars · Voices/models story · Build·Run·Test · Troubleshooting · Known cruft.

### whisper-service/CLAUDE.md — sections (Lancaster's outline)
Purpose · GPU/CPU story (CUDA-12 pin set, fallback ladder) · Model story (HF cache layout, re-seed via tar) · Endpoints/API · Config env vars · Build·Run · Troubleshooting (cuDNN, OOM, healthcheck quirks).

---

## 6. Decisions you need to make before mission #2

Numbered for easy reply.

1. **Root composes** — delete both, rewrite to match live state, or keep CPU variant only? (See §3c.)
2. **`nginx/` and `monitoring/`** — keep or kill? (Likely kill — depends on #1.)
3. **ffmpeg in piper Dockerfile** — kill it? (See §3a.)
4. **`piper-service/test_service.py`** — delete or properly resurrect?
5. **Commented `*_API_KEY` placeholders in `.env.example`** — drop?
6. **`.nelson/` directory** — gitignore (keep mission artifacts local) or commit the captain's log for posterity? Recommend gitignore.
7. **service.py code smells (§4)** — fix in mission #2 alongside CLAUDE.md writing, or punt to a separate cleanup mission later?

---

## 7. Suggested mission #2 plan

Once you've answered §6, mission #2 looks like:

1. Apply the §3 decisions (deletions / edits).
2. Write the three CLAUDE.md files from the outlines, using this ROADMAP as ground truth for facts (esp. the per-service-compose-is-canonical correction).
3. (Optional) Fix the service.py smells from §4 in the same pass — recommend doing the env-var alignment ones (§4 piper 2-4 and whisper 4-5,7) because they're trip hazards for future you.
4. Single commit (`sendit`), or two commits — one for cleanup, one for docs — your call.

---

## 8. Risks / open notes

- **The `logs/` dir is world-writable** (chmod 777 effectively) because containers write as UID 1001. Functional, but worth noting. Not changed this mission.
- **Default voice mismatch** between root compose (`en_US-amy-medium`) and per-service compose / live container (`en_US-lessac-medium`). Will resolve itself once root compose is dealt with.
- **`torchaudio` is in whisper `requirements.txt` but never imported.** Kept defensively as part of the CUDA-12 pin set — removing it risks dependency-resolver surprises. Leave alone.
- **CLAUDE.md at root is currently empty.** Mission #3 writes it.

---

## 9. Mission #2 completion summary (2026-05-10)

All §6 decisions and safe §4 smells applied. Per-captain detail in `.nelson/captains-log-mission-2.md`.

### Decisions applied
| § | Decision | Outcome |
|---|---|---|
| 6.1 | Root composes | **Deleted both** `docker-compose.yml`, `docker-compose.cpu.yml`. |
| 6.2 | `nginx/` + `monitoring/` | **Both directories deleted.** |
| 6.3 | ffmpeg in piper Dockerfile | **Removed.** Piper-service **rebuilt + smoke-tested** (`/health`, `/voices`, `/tts?format=opus` → all 200, valid Ogg-Opus output). Container healthy. |
| 6.4 | piper `test_service.py` | **Deleted.** |
| 6.5 | `*_API_KEY` placeholders | **Dropped.** Plus 8 root-compose-orphaned env keys (`PROXY_*`, `PROMETHEUS_PORT`, `WHISPER_*_PATH`, `PIPER_*_PATH`). |
| 6.6 | `.nelson/` gitignore | **Added.** |
| 6.7 | Safe code smells | **Applied — see below.** |

### Code smells fixed (the "safe" ones)
**piper-service:**
- Removed unused `import json`.
- Migrated `@app.on_event("startup"/"shutdown")` → `lifespan` async context manager.
- `asyncio.get_event_loop()` → `asyncio.get_running_loop()` inside coroutines.
- Removed unused config fields `max_concurrent_requests`, `model_cache_size` (and corresponding env reads + validators).
- Bonus: dropped now-dead `ENV PIPER_MAX_CONCURRENT` / `ENV PIPER_MODEL_CACHE_SIZE` from Dockerfile.

**whisper-service:**
- Migrated `@app.on_event("shutdown")` → `lifespan`.
- Added `WHISPER_LOG_FILE` to `.env.example`.

### Code smells DEFERRED to a future mission
- piper: BackgroundTask error swallowing, redundant model-existence check, `PIPER_MAX_TEXT_LENGTH` shadowing.
- whisper: dead `encode` param, dead `tsv` Literal, content-type validation gaps, hardcoded vs env-driven knob inconsistency, duplicate device-selection logic.

These are behavior-changing fixes; saved for a dedicated cleanup mission if the user chooses.

### What's next
- **Mission #3:** Write the three `CLAUDE.md` files (root, piper-service, whisper-service) using the outlines drafted by mission #1 captains, with this ROADMAP as ground truth.
- **Before mission #3:** Run `sendit` (or commit manually) to bank the cleanup work.
