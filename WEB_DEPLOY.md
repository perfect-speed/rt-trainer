# RT Trainer v0.5.1 – web deployment

Frontend: GitHub Pages from `main/docs`.
Backend: existing Render service `rt-trainer-api`.

## 1. Update source and backend

Commit/push the v0.5.1 source. Render should redeploy because `server/src/server.js` now includes `/api/speech`.

Check:

`https://rt-trainer-api.onrender.com/health`

Expected: `{"ok":true,"openaiConfigured":true}`.

## 2. Build GitHub Pages frontend

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com
```

The script runs `flutter pub get`, `flutter test`, builds for `/rt-trainer/`, copies the result to `docs/`, and creates `docs/.nojekyll`.

Then:

```powershell
git add .
git commit -m "Publish RT Trainer v0.5.1 mobile + TTS"
git push
```

## 3. Verify

GitHub Actions / Pages should finish green. Then test:

`https://perfect-speed.github.io/rt-trainer/`

Use a real phone in both portrait and landscape orientation and verify the audio prompt, `VISA TEXT`, and PTT flow.
