# RT Trainer v0.9.0

Experimental Swedish PPL radiotelephony trainer.

v0.9.0 freezes the successful v0.8 deterministic speech architecture and tests a new question: how much of the perceived "real radio" feeling comes from the communication channel rather than from the voice model itself?

The default pipeline is:

`typed operational message → deterministic phraseology → pronunciation representation → single-call TTS → deterministic VHF-style DSP → audio`

The speech content, TTS model, voice, speed and prompt are deliberately unchanged from the v0.8 baseline. The new RADIO condition only post-processes the synthesized 24 kHz PCM waveform with a light VHF-style channel model: bandwidth limiting, gentle compression/soft clipping, a low deterministic noise floor, and short PTT/squelch edge transients.

The UI provides an A/B condition:

- **RADIO · v0.9** — v0.8 speech plus channel DSP (default)
- **REN RÖST · v0.8** — the same underlying clean TTS waveform without DSP

Within one live backend process, both conditions reuse the same cached base TTS PCM for a given spoken script. This makes the comparison much cleaner: wording, controller voice and prosody are held constant while only the channel treatment changes.

Learner ASR, deterministic readback validation, warm-up, scenario/drill structure and exact replay caching remain unchanged.
