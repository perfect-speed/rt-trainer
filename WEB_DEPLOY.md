# Web deploy — v0.11.1

From the project root:

```powershell
flutter test
git status
git add .
git commit -m "v0.11.1 selective callsign flow"
git push
```

Wait for the Render backend deploy to succeed, then verify:

`https://rt-trainer-api.onrender.com/health`

Expected health markers include:

```json
{
  "version": "0.11.1",
  "speechDefault": "openai-v0.9.2-radio-dsp-pronunciation-chunking",
  "candidateSpeech": "openai-v0.11.1-selective-callsign-flow-radio-dsp"
}
```

Run locally against Render:

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

For the public GitHub Pages build:

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com -RepoName rt-trainer
git status
git add .
git commit -m "Deploy web v0.11.1"
git push
```
