# RT Trainer v0.6.7 – web deployment

## 1. Test Flutter source

```powershell
flutter test
```

## 2. Push source/backend

```powershell
git add .
git commit -m "Segment realtime ATC speech for content control"
git push
```

Wait until Render `rt-trainer-api` is **Live**. Verify `/health` reports
`version: 0.6.7`.

## 3. Verify locally against Render

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

Test **RÖST · REALTIME** first. Evaluate separately:

- all mandatory groups are actually spoken;
- Swedish callsign spelling remains correct;
- no extra operational information is introduced;
- rhythm inside each group;
- pauses/seams between groups;
- delay before playback starts.

The backend log should show `Realtime RT-aware audio verification accepted` for successful
transmissions. A rejected individual group is logged as
`Realtime segment guard rejected output`.

## 4. Build GitHub Pages after local verification

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com

git add docs
git commit -m "Build RT Trainer v0.6.7 web"
git push
```

Expected URL: `https://perfect-speed.github.io/rt-trainer/`
