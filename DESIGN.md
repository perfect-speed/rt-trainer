# RT Trainer v0.7.0 — Natural whole-utterance speech

## Design hypothesis

Recover the natural whole-utterance prosody seen in v0.6.0 while retaining the reliability work learned in v0.6.x.

**Scenario/world state owns reality. Realtime owns expression. Validation decides whether an expression is accepted.**

### Speech path

1. Flutter derives the deterministic Swedish spoken script from the normative ATC transmission.
2. Realtime generates the complete ATC transmission as one utterance — no segmented synthesis.
3. Realtime's output transcript must canonicalize to the exact spoken script. Extra words such as `svara` therefore reject the take.
4. A separate ASR pass listens to the actual waveform and verifies the hard operational payload (all digit sequences and, when confidently reconstructed, callsign). It does not reject acoustically ambiguous Q/K spelling in `Q N Helge`.
5. Rejected takes are regenerated as complete natural utterances, up to three attempts.
6. If all natural takes fail, deterministic TTS remains the no-sound safety fallback.
7. Accepted audio is cached; `LYSSNA IGEN` replays the exact same waveform with no network call.

### Preserved from v0.6.10

- Render warm-up before the first exercise.
- Stable configured controller voice.
- Client and server audio caching.
- Retry handling for transient backend errors.
- Detailed latency diagnostics.

### What v0.7.0 deliberately removes

- Segment-by-segment generation.
- Segment joins and per-segment prosody micromanagement.
- The assumption that more generation constraints automatically improve the learner experience.

The new control principle is: **control acceptance, not prosody.**
