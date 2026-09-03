# RT Trainer v0.8.0 – web deployment

## Local test

From the project folder:

```powershell
flutter pub get
flutter test
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

The default voice chip should show **RÖST · v0.8 TTS**. The alternate **RÖST · v0.7 REF** condition is kept only for A/B listening.

## Backend

Push the project and let Render redeploy `server/`. Wait until `rt-trainer-api` is **Live**. Verify `/health` reports:

- `version: 0.8.0`
- `speechDefault: deterministic-tts`

## Web build

```powershell
.\deploy_web.ps1
```

Then:

```powershell
git add .
git commit -m "Test deterministic ATC speech pipeline"
git push
```

GitHub Pages remains:

`https://perfect-speed.github.io/rt-trainer/`
