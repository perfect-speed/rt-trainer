# RT Trainer v0.9.1 – web deployment

From the project root on Windows:

```powershell
flutter test
git status
git add .
git commit -m "Add v0.9.1 prosodic chunking experiment"
git push
```

Wait until Render has deployed the backend. Its health response should report:

- `version: 0.9.1`
- `speechDefault: deterministic-tts-radio-dsp-prosodic-chunking`

Then run locally:

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

The default chip should show **RADIO · v0.9.1**. Listen especially to `Q N Helge` and the full registration. The experiment changes their prosodic grouping only; QNH/callsign values and the v0.9 radio DSP should remain unchanged.

For a public web build, use the existing `deploy_web.ps1`, then commit the regenerated `docs/` directory and push it.
