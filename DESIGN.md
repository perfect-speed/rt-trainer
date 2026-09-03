# RT Trainer v0.8.0 — deterministic speech pipeline experiment

## Hypothesis

A typed operational message plus deterministic phraseology/pronunciation rendering and a single full-utterance neural-TTS call can improve normative/acoustic reliability without the loss of naturalness caused by segmented speech generation.

## Architectural boundary under test

- Scenario/typed message owns operational values.
- Deterministic renderer owns normative wording.
- Pronunciation representation owns aviation-specific spoken forms.
- Neural TTS owns voice and prosody, but is not asked to choose operational content.
- Realtime speech-to-speech is retained only as a reference condition.

## Default speech path

`AtcMessage → normativeText → SwedishRtSpeechFormatter → gpt-4o-mini-tts → cached waveform`

The entire utterance is synthesized in one call. There is no token-level audio splicing and no ASR judge in the default path.

## Critical-token test set

The current five drills deliberately stress:

- full Swedish callsigns and spelling words;
- runway designators;
- `Q N Helge` and QNH values;
- frequencies;
- four-digit transponder codes;
- final-digit completion;
- absence of invented helper words such as `svara`.

## Important limitation

OpenAI's current TTS interface provides text plus voice/instructions, but this implementation does not have a true phoneme/lexicon API. Therefore v0.8.0 tests whether deterministic text/pronunciation representation is sufficient with the current TTS engine. If `Q N Helge` remains acoustically unreliable, that is evidence to test a TTS engine with explicit phoneme/pronunciation controls rather than adding more Realtime prompt guards.

## What is deliberately unchanged

- Flutter UI and PTT workflow;
- learner ASR;
- readback validation;
- scenario/drill structure;
- warm-up;
- exact replay cache.

This keeps the experiment focused on the ATC speech-production architecture.
