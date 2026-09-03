# RT Trainer v0.9.0 — VHF radio-channel experiment

## Result carried forward from v0.8

The five baseline cases produced correct `Q N Helge`, no invented `svara`, and no perceived loss of naturalness compared with the previous Realtime condition. v0.8 is therefore frozen as the speech-architecture baseline.

## Hypothesis

A substantial part of operational radio authenticity can be added *after* correct speech synthesis through a deterministic communication-channel model, without changing phraseology, operational content or the TTS voice.

This deliberately separates two constructs:

- **linguistic naturalness** — wording, pronunciation, voice and prosody;
- **radio-operational authenticity** — how that speech is transmitted through a VHF-like channel.

## Experimental comparison

Both conditions start from the same deterministic Swedish RT script and, while the backend instance remains alive, the same cached raw TTS PCM waveform.

### CLEAN — v0.8 baseline

`AtcMessage → deterministic renderer → pronunciation script → TTS PCM → WAV`

### RADIO — v0.9 experimental condition

`AtcMessage → deterministic renderer → pronunciation script → same TTS PCM → VHF DSP → WAV`

The only manipulated variable is post-synthesis channel treatment.

## DSP profile (deliberately mild)

The v0.9 RADIO profile uses:

- approximate 300–3300 Hz speech bandwidth;
- two gentle low-pass stages;
- light dynamic compression;
- soft saturation rather than hard clipping;
- very low deterministic noise floor;
- short PTT/carrier onset and squelch-like tail transients.

Noise is seeded from the spoken script so repeated generation is reproducible. Exact replay caching still ensures `LYSSNA IGEN` returns the same accepted waveform.

## What this version does NOT attempt

- no reduced intelligibility or deliberately poor reception;
- no fading, multipath, interference or blocked transmissions;
- no multiple radios/voices;
- no changed phraseology or digit style;
- no new learner-ASR logic;
- no state-model or traffic changes.

Those would confound the experiment.

## Test questions

For the same five baseline transmissions:

1. Does RADIO sound more like actual aircraft VHF than CLEAN?
2. Is intelligibility still fully adequate?
3. Does the channel treatment make the existing slightly stringent training speech feel more operationally natural, or merely more filtered?
4. Are PTT/squelch effects subtle enough not to become theatrical?
5. Does any critical token become harder to hear? If so, that is a failure of the current DSP profile.

## Decision rule

If RADIO improves authenticity without reducing intelligibility, keep channel simulation as a separate deterministic layer. If it merely degrades the audio, revert to CLEAN and adjust or abandon the DSP profile rather than changing the speech architecture.
