# Web deploy — v0.12.2

Backend first: commit/push and wait for Render. Verify `/health` reports `0.12.2`.

Local test:
`flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com`

Public web deploy after acceptance:
`./deploy_web.ps1 -BackendUrl https://rt-trainer-api.onrender.com -RepoName rt-trainer`
