# RT Trainer v0.5.3 – Natural Swedish ATC foundation

This version keeps the v0.5.1 mobile/PTT architecture and focuses on the ATC
experience before adding more functionality.

## Changes in v0.5.3

- Adds a deterministic Swedish RT speech formatter between scenario text and TTS.
- `QNH` is now spoken as **ku en hå** rather than being left to generic acronym pronunciation.
- Runways, QNH, transponder codes and frequencies are rendered digit-by-digit
  using the clarified Swedish forms: nolla, ett, tvåa, trea, fyra, femma, sexa,
  sju, åtta, nia.
- Swedish registrations are converted to the Swedish spelling alphabet before TTS.
- TTS instructions now prioritise natural Swedish ATC prosody rather than a
  textbook/read-aloud style.
- The normative scenario string remains unchanged and continues to own the facts.
- Adds regression tests for the speech formatting layer.
- Keeps v0.5.1 validation/radiotelephony logic unchanged.

Design principle: **Stringens i reglerna – realism i uttrycket – progression i komplexiteten.**

## Local check

```powershell
flutter test
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

For the new speech behaviour to work against Render, push the updated `server/`
first and wait until `rt-trainer-api` is Live.

## Web deployment

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com

git add .
git commit -m "Publish RT Trainer v0.5.3 natural Swedish ATC"
git push
```

The deploy script recreates `docs/.nojekyll` automatically.
