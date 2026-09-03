# RT Trainer v0.9.2

## Pronunciation chunk experiment

v0.9.2 keeps the deterministic speech architecture and VHF radio DSP from v0.9.x. The only intended experiment is an **internal pronunciation representation** before the single TTS call.

The learner still sees and the validator still uses the same normative content. Internally, familiar RT units are bound with hyphens so the TTS engine is encouraged to realize them as rhythmic chunks rather than word-by-word dictation.

Examples:

- `Q N Helge` → `Q-N-Helge`
- `Sigurd Erik Viktor Petter Tore` → `Sigurd-Erik-Viktor-Petter-Tore`

Digits are intentionally unchanged in this version because they already sound comparatively cohesive.

## Test focus
Compare with v0.9.1 and listen for:

1. correct and more fluent `Q N Helge`;
2. more cohesive registration spelling;
3. no loss of letters, extra words or critical values;
4. no audible hyphen artifacts.

If the improvement remains small, the next architectural experiment should use a speech engine with explicit pronunciation/phoneme control rather than further prompt tuning.
