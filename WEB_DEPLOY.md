# Web deploy — v0.10.0

## 1. Replace the project files

Unpack this release over the existing `rt_trainer` project (preserve your `.git` directory).

## 2. Test before commit

```powershell
flutter test
```

## 3. Commit and push

```powershell
git status
git add .
git commit -m "Add v0.10 explicit prosodic boundary experiment"
git push
```

## 4. Configure Render

In the Render service environment, add the Azure Speech key:

```text
AZURE_SPEECH_KEY=<your Azure Speech resource key>
```

The repository `render.yaml` supplies these non-secret defaults:

```text
AZURE_SPEECH_REGION=swedencentral
AZURE_TTS_VOICE=sv-SE-MattiasNeural
AZURE_RT_BREAK_MS=90
```

Keep the existing `OPENAI_API_KEY`; it is still used for learner ASR and the v0.9.2 baseline condition.

After push/configuration, wait for Render to deploy. Check:

```text
https://rt-trainer-api.onrender.com/health
```

Expected key fields include:

```json
{
  "version": "0.10.0",
  "azureSpeechConfigured": true,
  "speechDefault": "azure-ssml-radio-dsp-explicit-boundary-control"
}
```

## 5. Run locally against Render

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

## 6. Test order

For each of the five drill cases, use this order:

1. `AZURE · PLAIN`
2. `AZURE · 90 ms`
3. `BASE · v0.9.2`

The critical comparison is 1 vs 2. Listen for Q→N versus N→Helge spacing and callsign flow, especially SE-MBN. Verify that no spelling word or operational value is lost or merged.

## 7. Publish GitHub Pages after the experiment is accepted

Use the existing project deployment script:

```powershell
.\deploy_web.ps1

git status
git add docs
git commit -m "Publish RT Trainer v0.10 web build"
git push
```
