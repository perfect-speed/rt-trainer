# RT Trainer v0.8.0

Experimental Swedish PPL radiotelephony trainer.

v0.8.0 is an architecture experiment prompted by the v0.6–v0.7 speech-control trade-off. The default ATC speech path no longer uses Realtime speech-to-speech generation. Operational content is represented as typed `AtcMessage` data, rendered deterministically to normative phraseology, converted to a Swedish RT pronunciation script, and synthesized in one neural-TTS call.

The default pipeline is:

`typed operational message → deterministic phraseology → pronunciation representation → single-call TTS → audio`

Realtime whole-utterance speech is retained only as an A/B reference for naturalness. The first experiment asks whether deterministic wording plus neural TTS can preserve critical values and the Swedish `Q N Helge` expression without returning to the mechanical segmented speech of v0.6.x.

Warm-up and exact replay caching remain enabled. Learner ASR and the deterministic readback validator are intentionally unchanged in this version.
