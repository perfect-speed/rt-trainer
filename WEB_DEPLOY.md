# Web deploy — v0.9.2

From the project root on Windows:

```powershell
flutter test
git status
git add .
git commit -m "Add v0.9.2 pronunciation chunk experiment"
git push
```

Wait for the Render backend deployment to finish. Verify that `/health` reports:

- `version: 0.9.2`
- `speechDefault: deterministic-tts-radio-dsp-pronunciation-chunking`

Then run locally:

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

The default speech condition should display `RADIO · v0.9.2`. `REN RÖST · v0.9.2` uses the same pronunciation representation without VHF DSP.
