# RT Trainer v0.9.1

## Prosodic chunking experiment

v0.9.1 keeps the successful v0.8 deterministic speech pipeline and the v0.9 VHF radio DSP unchanged. The only intended experimental change is **prosodic grouping inside the TTS call**.

The working hypothesis is that operational correctness and naturalness can be separated: the deterministic representation owns the words and values, while TTS may control timing and prosody.

### What changes

- `Q N Helge` remains exactly the same deterministic script, but TTS is instructed to say it as one established radiotelephony chunk without audible pauses between Q, N and Helge.
- A full callsign such as `Sigurd Erik Gustav Ludvig Adam` is treated as one cohesive identity group rather than pedagogical spelling-word dictation.
- Short functional pauses remain **between** information groups.

### What does not change

- QNH, runway, callsign and transponder values remain deterministic.
- The clarified Swedish digit forms remain unchanged for this experiment.
- The v0.9 radio DSP remains unchanged.
- No audio-token splicing and no additional ASR verifier are introduced.

The default condition is **RADIO · v0.9.1**. **REN RÖST · v0.8** remains available as a clean reference.
