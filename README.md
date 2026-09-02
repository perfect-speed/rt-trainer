# RT Trainer v0.5.5 – Prosodic grouping

This iteration deliberately adds no new training functionality. It focuses on the perceived rhythm of Swedish radiotelephony.

## Changes in v0.5.5

- Introduces **prosodic grouping** as an explicit speech-design principle.
- QNH is rendered internally for TTS as `ku en Helge` so that it is heard as the compact Swedish RT expression **Q N Helge**, rather than three equally separated items.
- TTS instructions now distinguish strongly between:
  - **very short spacing within an information group**, and
  - **a short natural pause between information groups**.
- Callsigns are explicitly treated as one rhythmic identity group; the model is instructed not to insert isolated pauses between Swedish spelling words.
- QNH + pressure digits are one group; transponder is a separate group.
- No changes to the deterministic validation rules in this iteration.

The design rule remains:

> Stringens i reglerna – realism i uttrycket – progression i komplexiteten.

## Verification

After copying the files into the project directory:

```powershell
flutter test
```

No new Flutter dependency has been added, so `flutter pub get` is not required solely for this version.

Suggested commit message:

```powershell
git commit -m "Add prosodic grouping to Swedish RT speech"
```
