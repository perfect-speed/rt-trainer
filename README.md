# RT Trainer v0.7.0

Experimental Swedish PPL radiotelephony trainer. v0.7.0 returns to natural complete Realtime utterances and performs deterministic post-validation before playback. Warm-up and exact replay caching from v0.6.10 are retained.

Run locally against the deployed backend:

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

Before committing:

```powershell
flutter test
```
