# RT Trainer v0.9.0 – web deployment

## Local test

From the project folder:

```powershell
flutter pub get
flutter test
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

The default voice chip should show **RADIO · v0.9**. Toggle it to **REN RÖST · v0.8** for the clean A/B reference. The two conditions use the same deterministic Swedish RT script; while the backend instance remains alive they also share the same cached base TTS PCM before v0.9 applies DSP.

## Backend

Push the project and let Render redeploy `server/`. Wait until `rt-trainer-api` is **Live**. Verify `/health` reports:

- `version: 0.9.0`
- `speechDefault: deterministic-tts-radio-dsp`

## Web build

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com
```

Then:

```powershell
git add .
git commit -m "Test VHF radio channel DSP against clean v0.8 speech"
git push
```

GitHub Pages remains:

`https://perfect-speed.github.io/rt-trainer/`
