# RT Trainer v0.6.4 – Segmented controlled speech

## Design principle

**Stringens i reglerna – realism i uttrycket – progression i komplexiteten.**

The scenario/world state owns operational truth. Generative audio is allowed to
realize speech, but not to choose or alter runway, QNH, transponder, frequency,
callsign or clearance content.

## Why v0.6.4

v0.5.x gave high content control but limited naturalness. v0.6.0 showed that a
Realtime audio model could sound substantially more natural, but it could also
add information. v0.6.1–0.6.2 introduced an output-content guard; testing then
showed the opposite failure mode: the model could omit a mandatory final group
such as `transponder 4255`, and the guard correctly rejected the audio.

The next hypothesis is therefore structural rather than prompt tuning:
**reduce the generative task size.**

## Architecture

```text
Scenario / world state
        |
        v
Deterministic normative ATC text
        |
        v
Deterministic Swedish spoken script
        |
        v
Deterministic segmentation
  [callsign] [runway] [QNH] [transponder] ...
        |
        v
Realtime realization + content guard PER SEGMENT
        |
        v
Accepted PCM segments
        |
        v
trim / short controlled join / concatenate
        |
        v
one WAV to learner
```

The model receives the full transmission only as prosodic context. It is told
to speak one exact current segment and never continue into the next segment.
Each generated segment must pass the same canonical content comparison used by
the speech guard. A failed segment is retried once; if it still fails, the
whole speech request fails rather than presenting incorrect operational audio.

## Segmentation

Current micro-exercises already use comma-delimited information groups. v0.6.4
preserves that deterministic grouping. A decimal comma without following
whitespace is not treated as a group separator.

Generated PCM has leading/trailing near-silence trimmed conservatively and a
small configurable join gap is inserted between accepted groups. Default:

```text
OPENAI_REALTIME_SEGMENT_GAP_MS=65
```

This is an experimental parameter, not a normative RT value.

## What v0.6.4 is intended to test

The primary observations are:

- Does every mandatory information group survive generation unchanged?
- Does natural ATC-like prosody remain inside each short group?
- Do independently generated groups create audible seams, tempo changes or
  unnatural pauses when concatenated?
- What latency penalty results from sequential generation?

This version deliberately adds no new training content. v0.5.5 remains the
conventional TTS baseline, while v0.6.0 remains an important reference for
high naturalness with insufficient content control.

## v0.6.4: stabilisering av segmenterat tal

Tre lager hålls isär:

1. **Normativt objekt:** exempelvis `QNH = 1018`.
2. **Talrealisation:** QNH får det uttalsorienterade manuset `ku enn Helge`; värdet genereras deterministiskt siffra för siffra.
3. **ASR-normalisering:** vanliga feltolkningar av själva etiketten, exempelvis `Tune Helge`, får reduceras till `qnh`, men talvärdet får aldrig ersättas med facit.

Ljudsegmenteringens sluttrimning är borttagen. Det är en medveten robusthetsprioritering: innehållsintegritet väger tyngre än minimalt mellanrum mellan segment.
