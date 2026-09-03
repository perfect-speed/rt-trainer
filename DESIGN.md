# RT Trainer v0.9.2 — Pronunciation chunk experiment

## Question
v0.9.1 showed that prosody instructions improved `Q N Helge` and spelled registrations slightly, but they still sounded more segmented than familiar numeric groups such as `1009`.

The hypothesis for v0.9.2 is that **the TTS input representation itself influences rhythmic grouping more strongly than prompt-only prosody instructions**.

## What changes
The normative ATC message and the deterministic Swedish RT formatter remain unchanged.

Immediately before the single TTS call, the backend creates a hidden pronunciation representation:

- `Q N Helge` → `Q-N-Helge`
- a callsign such as `Sigurd Erik Gustav Ludvig Adam` → `Sigurd-Erik-Gustav-Ludvig-Adam`

The hyphens are internal binding cues only. The TTS instruction explicitly says not to pronounce them as words or pauses.

## What does not change
- typed operational values;
- deterministic phraseology;
- Swedish clarified digit words;
- one full-utterance TTS call;
- v0.9 VHF DSP;
- learner ASR;
- validator;
- exercise set.

## Falsification
The experiment fails if any of the following occurs:

- Q is again perceived as K;
- `Q-N-Helge` loses a component;
- callsign spelling becomes less intelligible;
- hyphens create audible pauses or unnatural compound-word pronunciation;
- flow is not meaningfully better than v0.9.1.

If the gain is only marginal, stop tuning prompt/orthography and test a TTS engine with explicit pronunciation/phoneme control instead.
