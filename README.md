# RT Trainer v0.7.1

Experimental Swedish PPL radiotelephony trainer. v0.7.1 keeps the natural whole-utterance architecture from v0.7.0 and stabilizes the Swedish QNH pronunciation. The normative scenario still stores `QNH`; only the internal speech-realization layer uses the acoustic cue `ku enn Helge` so Realtime is less likely to produce `KN Helge`. Warm-up, post-validation and exact replay caching are unchanged.

Run locally against the deployed backend:

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

Before committing:

```powershell
flutter test
```
