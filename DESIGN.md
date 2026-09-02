# RT Trainer v0.6.9 – Prosodic stability

## Design goal

Keep the natural Realtime voice achieved in v0.6.x while making segment endings
and information-group rhythm more reproducible.

> Stringens i reglerna – realism i uttrycket – progression i komplexiteten.

## Why v0.6.9 exists

v0.6.7 was operationally much more robust: audio started reliably and several
cases were fully acceptable. Remaining faults were narrow and acoustic/prosodic:
occasionally half of the final digit in a transponder code or QNH was lost,
QNH could be read too slowly, and an individual spelling word such as `Martin`
could receive excessive duration.

Those observations argue against changing the overall architecture. v0.6.9
therefore changes only the speech-realisation boundary.

## Architecture

```text
Deterministic scenario
        |
        v
Locked Swedish RT script
        |
        v
Segment-specific prosody instruction
        |
        v
Segmented Realtime audio
        |
        +--> Realtime transcript guard
        |
        +--> independent RT-aware audio ASR
        |
        +--> acoustic endpoint/tail guard
        |
        v
Accepted PCM + deterministic tail padding
        |
        v
Concatenated ATC transmission
        |
        +--> if Realtime fails: exact-script TTS fallback
```

## Prosody policy

- Callsign: one compact identity group with even rhythmic weight. Do not stretch
  any single Swedish spelling word.
- QNH: `Q N Helge` plus pressure is a compact information group, not dictation.
- Transponder: the four digits form one rhythmic group; the fourth digit must be
  fully completed.
- Runway/frequency: normal Swedish RT cadence, concise rather than pedagogical.
- Every segment must complete its final token before ending.

## Acoustic tail guard

Independent transcription can recognise a word even if the audible endpoint is
perceptually clipped. v0.6.9 therefore also looks at the waveform endpoint.
Realtime is asked to leave a tiny pause after the final token. If the last
55 ms is still too energetic (RMS/peak threshold), that generation is retried.
This is a heuristic safety signal, not semantic verification.

After acceptance, 120 ms of zero PCM is appended deterministically. The
inter-segment join gap is only 30 ms. This gives the final phoneme room to decay
without recreating the slow, separated cadence that earlier versions produced.

## Resilience / no-silence policy

A Realtime content, ASR or acoustic-tail rejection does not directly become a
502. The backend retries the segment; if verified Realtime speech still cannot
be produced, it falls back to deterministic exact-script TTS. The TTS fallback
itself gets two attempts and a safe tail. Client-side transient HTTP retry from
v0.6.7 remains in place for Render cold-start/deployment errors.

This cannot guarantee audio through a total network/API outage, but it prevents
our own speech guards from being the sole cause of a silent exercise.


## v0.6.9 – stable voice, cached replay, lower latency
- First accepted waveform is cached in the Flutter client per exercise + speech engine. `LYSSNA IGEN` replays identical bytes and never regenerates the controller voice.
- The backend also keeps a small in-memory cache of accepted waveforms while the Render instance is alive.
- Audio bytes are cached **before** playback, so a browser autoplay rejection does not force regeneration; an explicit replay can use the already fetched waveform.
- Independent speech segments are generated and verified concurrently, then reassembled in deterministic order. This reduces first-play latency without changing normative ownership.
- Repeated equal QNH digits (e.g. 1009) receive a short perceptual separation instruction, while keeping compact ATC rhythm.
- Realtime voice remains explicitly fixed by `OPENAI_REALTIME_VOICE`; retries use the same configured voice. A TTS fallback can still sound different, but once accepted the resulting full waveform is stable for that exercise.
