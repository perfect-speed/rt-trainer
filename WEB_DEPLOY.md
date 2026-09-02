# RT Trainer v0.5.3 – web deployment

## 1. Test source

```powershell
flutter test
```

## 2. Push source/backend

```powershell
git add .
git commit -m "Publish RT Trainer v0.5.3 natural Swedish ATC"
git push
```

Wait until Render `rt-trainer-api` is **Live**. The speech endpoint contains the
new natural Swedish ATC instructions.

## 3. Verify locally against Render

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

Check especially:
- QNH is heard as **ku en hå**.
- Swedish spelling alphabet sounds natural.
- runway/QNH/transponder digits are clear but not over-articulated.
- PTT/transcription and deterministic validation are unchanged.

## 4. Build GitHub Pages

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com

git add docs
git commit -m "Build RT Trainer v0.5.3 web"
git push
```

Expected URL: `https://perfect-speed.github.io/rt-trainer/`
