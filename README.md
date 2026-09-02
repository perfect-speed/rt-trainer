# RT Trainer v0.5.1 – Mobile + spoken ATC

This version is based on v0.5 Web Demo and deliberately leaves the readback validator/radiotelephony rules unchanged.

## Changes in v0.5.1

- Responsive mobile layout: phones and low-height landscape screens no longer use the desktop layout.
- Compact header/progress/navigation on phones.
- In very low landscape view, text-entry controls are hidden so PTT remains the primary interaction.
- ATC exercise prompts are spoken through the backend using OpenAI TTS.
- ATC prompt text is hidden by default. `VISA TEXT` exposes it as learner support.
- `LYSSNA IGEN` repeats the current ATC transmission.
- Spoken prompt strings explicitly use Swedish digit-by-digit runway/frequency pronunciation and Swedish spelling words, rather than letting TTS infer how numeric text should be read.
- `deploy_web.ps1` now creates `docs/.nojekyll` automatically.

## Local test

Backend:

```powershell
cd server
npm install
npm start
```

Flutter, from project root:

```powershell
flutter pub get
flutter test
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=http://localhost:8080
```

## Render

The new `/api/speech` endpoint defaults to:

- `OPENAI_TTS_MODEL=gpt-4o-mini-tts`
- `OPENAI_TTS_VOICE=alloy`

These variables are optional because the server has defaults. The existing `OPENAI_API_KEY` remains server-side only.

After the code is pushed to the existing GitHub repository, Render can redeploy the backend automatically.

## GitHub Pages build

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com

git add .
git commit -m "Publish RT Trainer v0.5.1 mobile + TTS"
git push
```

Expected public URL:

`https://perfect-speed.github.io/rt-trainer/`

## Test focus

1. Portrait phone: no horizontal overflow/scaled desktop layout.
2. Landscape phone: compact header and PTT remain visible/useful.
3. Start an exercise: ATC should be heard; if browser autoplay blocks it, use `LYSSNA IGEN`.
4. Prompt text should initially be hidden and visible only after `VISA TEXT`.
5. Verify spoken runway 19 is “ett nia”, runway 01 is “nolla ett”, and callsigns use the Swedish spelling alphabet. The demo TTS deliberately uses the clarified Swedish radiotelephony digit forms: nolla, ett, tvåa, trea, fyra, femma, sexa, sju, åtta, nia.
6. PTT → transcription → deterministic validation should behave exactly as in v0.5.


## Swedish digit pronunciation

The demo voice uses the clarified Swedish radiotelephony digit forms: **nolla, ett, tvåa, trea, fyra, femma, sexa, sju, åtta, nia**. The speech normalizer accepts both clarified forms and ordinary Swedish forms (for example `noll`/`nolla`, `två`/`tvåa`, `fem`/`femma`, `nio`/`nia`) as the same numeric value. We deliberately do not score ordinary pronunciation as a learner error yet, because ASR may not preserve the final vowel reliably enough for a fair automatic phraseology grade.
