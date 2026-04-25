# Toji Services — Workspace Guide

This repo is the source for the dockerized speech services that power the
**Toji v2** Discord voice bot. The bot itself lives at `/home/travis/toji2/`
(TypeScript on Bun). Only `piper-service` (TTS) is actively maintained from
this workspace right now; `whisper-service` is included for completeness but
the running STT container has not been touched in months.

The active machine is `oracle` (the box you're on). Every service in this
repo runs as a Docker container against bind-mounted data in
`/home/travis/services/` (a separate, data-only directory — do not confuse
the two).

---

## Where things live

| Path | What it is |
|---|---|
| `/home/travis/toji-services-src/` | This repo — the source of truth |
| `/home/travis/services/` | Runtime data: models, logs (do **not** edit code here) |
| `/home/travis/toji2/` | The Discord bot that consumes these services |
| `Krenuds/toji-services` (GitHub) | Remote for this repo |

Bind mount in production: `/home/travis/services/data/piper/models` →
`/app/models/piper` inside the container.

---

## Deploy loop

```bash
cd /home/travis/toji-services-src/piper-service
docker-compose build           # builds piper-service-piper-service:latest
docker-compose up -d           # recreates the running container in place
docker logs -f piper-service   # tail to confirm healthy startup
```

`docker-compose.yml` in this directory is the **only** orchestration file
that matches reality. It declares the running container's name, port,
bind mount, env vars, and healthcheck. Do not edit these without
verifying against `docker inspect piper-service` first — the file was
reconciled with the live container on 2026-04-25 after a long period of
hand-launched drift.

To roll back to a previous image:
```bash
docker stop piper-service && docker rm piper-service
docker run -d --name piper-service -p 9001:9001 \
  -v /home/travis/services/data/piper/models:/app/models/piper \
  -e PIPER_DEFAULT_VOICE=en_US-lessac-medium \
  --restart unless-stopped <image-sha>
```

---

## Current state

- Image: `piper-service-piper-service:latest`
- Default voice: `en_US-lessac-medium` (22050 Hz mono)
- Endpoint: `POST /tts` returns `audio/wav`
- Health: `GET /health`
- The service has **no Opus support today**. Adding it is the active work
  — see `docs/opus-output-roadmap.md`.

---

## Coupling to toji2

The bot calls `POST http://localhost:9001/tts` for every spoken reply.
Today it parses the returned WAV header, extracts PCM, resamples
22k mono → 48k stereo, and feeds the result to discord.js. That whole
client-side pipeline goes away once this service can emit Ogg-Opus
directly. The toji2 side of the migration is tracked in
`/home/travis/toji2/docs/audio-opus-unification.md`.

When you change the API contract here, the bot's `TtsClient.ts` and
`PlaybackBus.ts` change in lockstep. Coordinate the two repos — break
the bot once and you'll be debugging two things at once.

---

## What this repo is *not*

- Not the place to run the bot. `toji2` does that.
- Not the place to debug Discord voice playback. The bot's
  `src/voice/CLAUDE.md` covers that path.
- Not the place to store models or logs. Those live under
  `/home/travis/services/`, mounted in.

Historical docs (`docs/MIGRATION_PLAN.md`, `docs/ARCHITECTURE.md`) describe
the original 2025 extraction from the monolith. They're kept for context
but do not reflect current operational reality — this file does.
