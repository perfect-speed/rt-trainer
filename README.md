# RT Trainer v0.11.1

## Selective callsign flow

v0.11.1 follows the listening result from v0.11.0: the local-flow treatment improved spelled Swedish registrations, while Q N Helge showed no clear benefit.

The experiment is therefore narrowed further:

- **BASE · v0.9.2** — frozen OpenAI speech baseline.
- **FLOW · v0.11.1** — only the leading spelled callsign is synthesized as a slightly faster identity group.
- **Q N Helge and the remainder of the ATC transmission** return to the frozen v0.9.2 baseline path.
- The v0.9 VHF radio DSP remains unchanged.

This is intentionally a minimal intervention: retain the observed gain for registrations without applying the same prosodic treatment to QNH.

## Run locally

```powershell
flutter test
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

## Backend health

`https://rt-trainer-api.onrender.com/health` should report version `0.11.1`.
