# RT Trainer v0.7.0 – web deployment

## 1. Test Flutter source

```powershell
flutter test
```

## 2. Push source/backend

```powershell
git add .
git commit -m "Add backend warmup and speech latency diagnostics"
git push
```

Wait until Render `rt-trainer-api` is **Live**. Verify `/health` reports `version: 0.7.0`.

## 3. Verify locally against Render

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

For the latency test, let Render become idle before one trial if possible. Open the welcome screen and note whether it shows `Röstserver klar.` before pressing **STARTA DEMO**. Then compare:

- time from STARTA DEMO to first SE-KQX audio;
- subsequent case latency;
- SE-GLA and SE-RYD callsign rhythm;
- immediate/identical `LYSSNA IGEN` replay.

In Render logs inspect `Warm-up ping`, `Speech request received`, `Realtime segment diagnostic`, and `Speech request timing`.

## 4. Build GitHub Pages after local verification

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com

git add docs
git commit -m "Build RT Trainer v0.7.0 web"
git push
```

Expected URL: `https://perfect-speed.github.io/rt-trainer/`
