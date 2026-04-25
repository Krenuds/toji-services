# Roadmap — Opus Output for `piper-service`

## Goal

Make `piper-service` capable of emitting Ogg-Opus audio in addition to
WAV, so the toji2 bot can stop doing client-side WAV decoding,
resampling, and runtime Opus encoding. The service becomes a clean
Ogg-Opus source; the bot becomes a dumb pipe to the Discord voice
gateway.

## Why this lives here, not in the bot

Piper synthesizes raw PCM internally — every neural TTS does. The
WAV-to-Opus encode has to happen *somewhere* in the pipeline. Doing it
inside the service puts the encode at the architectural boundary
(at the same place the audio leaves Docker), and lets every consumer
of the service benefit instead of just toji2. It also pulls FFmpeg
out of the bot runtime, where we explicitly do not want it.

## Scope

Single endpoint change to `service.py`, plus a one-line Dockerfile
addition. Backward compatible — existing callers requesting WAV get
the same bytes they get today. No change to the Whisper service.

## Open questions to resolve before merging

- **Resample location.** Piper outputs 22050 Hz mono. Discord wants
  48 kHz. FFmpeg can resample inline (`-ar 48000 -ac 2`) as part of the
  same pipeline that encodes Opus. Decision to make: do that inside
  the service, or leave it 22k mono in the Ogg-Opus output and let
  Opus's built-in handling cover it? Worth a quick A/B before locking in.
- **Bitrate for speech.** `voip` application mode at 64 kbps is the
  standard recommendation for speech. Confirm intelligibility on a
  real reply before we ship.
- **Chunking semantics.** The bot today receives one WAV per sentence
  chunk and concatenates samples. Ogg has page-level framing — you
  cannot byte-concat two Ogg streams and get a valid one. Either the
  service handles chunking internally (one request → one Ogg covering
  the full reply), or the bot calls `/tts` per chunk and queues each
  Ogg as a separate playback resource. Coordinate with toji2 before
  picking.

## Phases

Each phase ends with a regression check against the bot before moving on.

### Phase 0 — baseline (done 2026-04-25)

- Compose file reconciled with running container.
- Deploy loop validated: `docker-compose build && docker-compose up -d`
  recreates `piper-service` in place. Health and `/tts` confirmed
  on the unchanged image.

### Phase 1 — add Opus path

1. **`piper-service/Dockerfile`** — add `ffmpeg` to the apt-get install
   line. Verify: `docker exec piper-service ffmpeg -version`.
2. **`piper-service/service.py`**
   - Add `format: Literal["wav", "opus"] = "wav"` to `TTSRequest`.
   - After `synthesize_audio_sync()`, branch on format. For `"opus"`,
     pipe the WAV bytes through:
     ```
     ffmpeg -loglevel error -i pipe:0 \
       -ar 48000 -ac 2 \
       -c:a libopus -b:a 64k -application voip \
       -f ogg pipe:1
     ```
     Return the resulting bytes with `media_type="audio/ogg"`.
   - WAV branch is unchanged. Default stays `"wav"` until the bot
     side cuts over.
3. **Local regression** — `curl` the WAV path with the same input we
   used for the post-Phase-0 sanity test. Bytes should be byte-identical
   (or at minimum same length and `ffprobe` output) to confirm the
   refactor didn't perturb the existing path.
4. **Local Opus check** — `curl ... -H 'format: opus'` (or in the JSON
   body), pipe to `ffprobe`, confirm a valid Ogg-Opus stream comes back.
5. **Commit + push.** Rebuild the container. Bot continues to work
   on the WAV path — no toji2 changes yet.

### Phase 2 — toji2 cuts over

Tracked in `/home/travis/toji2/docs/audio-opus-unification.md`. Once
that ships, the WAV branch in this service becomes dead code — leave
it in place for one release as documentation, then remove it in a
follow-up commit. Do not remove and cut over in the same PR.

## Files this phase touches

- `piper-service/service.py`
- `piper-service/Dockerfile`
- `docs/opus-output-roadmap.md` (this doc — update phase status)

## Out of scope

- Whisper service. Untouched.
- Any change to the model bind mount, port, or healthcheck.
- Removing the WAV branch (separate, later commit).
