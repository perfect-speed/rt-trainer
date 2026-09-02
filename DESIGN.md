# RT Trainer v0.6.1 – Realtime voice architecture prototype

## Design principle

**Stringens i reglerna – realism i uttrycket – progression i komplexiteten.**

v0.5.x established a deterministic world state, deterministic readback validation, Swedish ASR normalization and a conventional text-to-speech layer. Repeated tuning improved pronunciation but produced diminishing returns in prosody.

v0.6.1 deliberately changes the speech architecture rather than adding more TTS exceptions.

## Architecture

```text
Scenario / world state
        |
        | normative ATC text
        v
Realtime speech realization
        |
        | generated audio only
        v
Learner hears ATC

Learner PTT -> ASR -> deterministic normalization -> deterministic validator
```

The scenario remains the source of operational truth. The Realtime model is not allowed to choose runway, QNH, squawk, frequency or callsign. It receives an already-fixed ATC transmission and is asked only to realize it as natural Swedish radio speech.

## Why Realtime

The previous chain was:

`scenario -> phonetic rewrite -> generic TTS -> audio`

This gave explicit pronunciation control, but callsigns and information groups often inherited uniform synthetic spacing. v0.6.1 instead sends the normative transmission directly to a Realtime audio model with domain instructions. The hypothesis is that a native audio model can preserve more natural rhythm and grouping than a TTS system reading a heavily phonetic script.

## A/B baseline

The v0.5.5 TTS path is intentionally retained. The UI has a compact switch between:

- **RÖST · REALTIME** – v0.6.1 experimental speech path, default.
- **RÖST · TTS BAS** – v0.5.5-style deterministic pronunciation + TTS baseline.

This is not intended as a learner-facing feature long term. It creates a controlled comparison during development and later supports formal expert rating.

## Research implication

The key research question is not whether a generative model can invent plausible ATC. It is whether a generative audio realization layer can increase perceptual realism while a deterministic scenario layer retains normative and operational control.

Candidate comparison dimensions:

- naturalness / ATC feel
- prosodic grouping
- intelligibility for novice learners
- exact preservation of operational values
- latency
- consistency across callsigns and numeric groups

v0.5.5 is frozen as the conventional TTS baseline for this comparison.

## v0.6.1 — Locked wording, generative prosody

Realtime no longer owns wording. The deterministic Swedish RT formatter produces an exact spoken script (for example Swedish spelling-alphabet words and `Q N Helge`). Realtime owns only prosody and voice realization.

The backend also collects the model's output-audio transcript and rejects/retries a response if the spoken words differ from the exact script. This is a content guard against additions such as an unassigned transponder code. In research terms, v0.6.1 narrows generative freedom from **expression** to **prosodic realization**.
