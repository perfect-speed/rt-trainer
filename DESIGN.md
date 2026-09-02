# RT Trainer v0.6.10 – Warm start and latency diagnostics

## Goal

Preserve the natural, repeatable voice achieved in v0.6.9 while separating two latency mechanisms:

1. **platform cold start** – Render waking the Node service after inactivity;
2. **normal speech latency** – Realtime generation, independent audio verification, retries and assembly.

## Warm-up path

```text
Welcome screen opens
        |
        +--> GET /api/warmup  (starts immediately)
        |
Learner reads instructions
        |
STARTA DEMO
        |
        +--> await same warm-up Future if still pending
        |
Trainer opens
        |
        +--> first real /api/speech request
```

The warm-up endpoint performs no speech generation and consumes no OpenAI audio call. Its purpose is to make the Render process live before the first operational request.

## Latency instrumentation

Backend logs now expose measurement points around the speech pipeline:

```text
Speech request received
  requestId
  uptimeSeconds

Realtime segment diagnostic
  generationMs
  verificationMs
  elapsedMs

Realtime segmented speech accepted
  totalMs

Speech request timing
  cache HIT/MISS
  engine/fallback
  totalMs
```

If the first request arrives with `uptimeSeconds` close to zero after a long browser wait, the long delay occurred in the hosting cold start before application code could serve the request. If `uptimeSeconds` is already high but `totalMs` is large, the bottleneck is inside the speech pipeline.

## Callsign rhythm

A Swedish registration is treated as one identity group. Realtime is explicitly instructed not to create a boundary after the initial `Sigurd Erik`. The target rhythm is even across all five spelling words, including SE-GLA and SE-RYD.

## Invariants retained

- deterministic scenario owns operational truth;
- Realtime owns voice/prosody only;
- independent audio verification remains active;
- unsafe/failed Realtime audio falls back to exact-script TTS;
- accepted audio is cached before playback;
- `LYSSNA IGEN` never regenerates accepted audio.
