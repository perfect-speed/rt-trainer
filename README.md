# RT Trainer v0.5.4 – ATC prosody + robust frequency parsing

This version keeps the v0.5.1 mobile/PTT architecture and focuses on the ATC
experience before adding more functionality.

## Changes in v0.5.4

- Accepts Swedish VHF frequency readback both with and without an explicitly spoken `komma`.
- Handles clarified digit forms such as `tvåa`/`femma` around the decimal marker.
- Uses the higher-quality `cedar` TTS voice by default and a slightly tighter radio pace.
- Refines the speech prompt toward natural Swedish ATC prosody rather than narrator-style speech.
- Keeps the normative scenario text separate from the spoken presentation layer.

## Local check

```powershell
flutter test
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

For the new speech behaviour to work against Render, push the updated `server/`
first and wait until `rt-trainer-api` is Live.

## Web deployment

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com

git add .
git commit -m "Publish RT Trainer v0.5.4 ATC prosody"
git push
```

The deploy script recreates `docs/.nojekyll` automatically.
