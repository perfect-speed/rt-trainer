# RT Trainer v0.10.1

## v0.10.1 change

The speech synthesis experiment itself is unchanged. This release makes the A/B test easier to run now that Azure Speech is configured: selecting any speech condition immediately replays the current ATC utterance, so the operational message, deterministic phraseology and radio DSP remain constant while only synthesis/prosody changes.


v0.10.1 is a controlled **explicit prosodic boundary** experiment. The operational message model, deterministic Swedish phraseology, learner ASR/validation, and the v0.9 VHF radio DSP are frozen.

The experiment adds Azure Speech SSML as a controllable timing layer and exposes three post-DSP listening conditions:

- `AZURE · 90 ms` — Azure Swedish neural TTS with explicit 90 ms internal `<break>` timing inside callsign spelling groups and `Q N Helge`.
- `AZURE · PLAIN` — the same Azure voice without explicit internal SSML timing. This is the same-engine control.
- `BASE · v0.9.2` — the frozen OpenAI pronunciation-chunk baseline from v0.9.2.

The purpose is not to find the perfect voice yet. It is to answer one narrow architectural question: **does documented, explicit phrase-boundary timing materially improve Swedish RT grouping without reducing intelligibility?**

## Required backend environment

Existing OpenAI variables remain required for learner transcription/debrief and the v0.9.2 baseline. Add:

```text
AZURE_SPEECH_KEY=<your Speech resource key>
AZURE_SPEECH_REGION=swedencentral
AZURE_TTS_VOICE=sv-SE-MattiasNeural
AZURE_RT_BREAK_MS=90
```

`AZURE_RT_BREAK_MS` is deliberately configurable so a later controlled run can test another fixed value without rewriting the phraseology layer.

## Test focus

Use the same five drill cases as v0.9.2. Compare `AZURE · 90 ms` first against `AZURE · PLAIN`, because that isolates SSML timing while keeping the voice and synthesis engine constant. Then compare both against `BASE · v0.9.2`.

Listen especially for the Q→N interval in `Q N Helge`, N→Helge as the internal reference, within-callsign spacing (especially SE-MBN), lost/merged spelling words, changed critical values, and whether the frozen radio DSP masks or exaggerates any difference.
