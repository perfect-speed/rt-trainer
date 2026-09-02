# RT Trainer v0.6.10 – Warm start and latency diagnostics

v0.6.10 keeps the stable voice/cache/verification architecture from v0.6.9 and targets the remaining first-play delay plus callsign rhythm.

### Changes

- The welcome screen sends `/api/warmup` immediately, while the learner reads the instructions. On Render this wakes the Node service before the first ATC speech request.
- `STARTA DEMO` waits for that same warm-up request if it is still in progress, and shows `STARTAR RÖSTSERVER…` rather than silently moving into a cold first exercise.
- Backend speech logs now include request receipt, process uptime, cache hit/miss, total request time, and per-segment generation/verification time. A first request with very low `uptimeSeconds` is strong evidence of a Render cold start.
- Existing client and server audio caches are unchanged: `LYSSNA IGEN` replays identical bytes immediately.
- Callsign prosody is tightened so the five Swedish spelling words form one compact identity group, without an extra pause after `Sigurd Erik` in examples such as SE-GLA and SE-RYD.
- No changes to deterministic scenario truth, readback validation, QNH/transponder verification, no-silence fallback, or speech segmentation.

The purpose of this version is diagnostic as well as practical: distinguish platform cold-start latency from normal speech-pipeline latency before optimising the verification architecture.
