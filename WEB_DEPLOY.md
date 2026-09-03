# Web deploy — v0.12.0

From the project root:

```powershell
flutter test
git status
git add .
git commit -m "v0.12.0 Scenario Foundation"
git push
```

Wait for Render and verify:

`https://rt-trainer-api.onrender.com/health`

Expected: `version: 0.12.0`, `scenarioFoundation: true`.

For GitHub Pages:

```powershell
.\deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com -RepoName rt-trainer
git status
git add .
git commit -m "Deploy web v0.12.0"
git push
```
