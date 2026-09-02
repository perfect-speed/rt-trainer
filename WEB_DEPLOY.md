# RT Trainer v0.5 Demo – webbpublicering

Arkitektur:

- Flutter-webbappen publiceras med GitHub Pages.
- Node-backend publiceras separat och innehåller OpenAI-nyckeln.
- API-nyckeln får aldrig läggas i Flutter-koden, `docs/` eller GitHub.

## 1. Backend

Projektet innehåller `render.yaml` för en Node-webbtjänst.

När backend är publicerad ska `/health` svara med JSON där `ok` är `true` och `openaiConfigured` är `true`.

Miljövariabler på backend:

- `OPENAI_API_KEY` = hemlig API-nyckel
- `OPENAI_TRANSCRIBE_MODEL` = `gpt-4o-transcribe`
- `OPENAI_MODEL` = `gpt-5.4-mini`
- `ALLOWED_ORIGIN` = `https://perfect-speed.github.io,http://localhost:5000`

Spara backendens publika HTTPS-adress, t.ex. `https://rt-trainer-api.example.com`.

## 2. Bygg GitHub Pages-versionen

Från projektroten i PowerShell:

```powershell
.\deploy_web.ps1 -BackendUrl "https://DIN-BACKEND-ADRESS" -RepoName "rt-trainer"
```

Skriptet kör tester, bygger Flutter för GitHub Pages och kopierar resultatet till `docs/`.

## 3. Git

```powershell
git add .
git commit -m "Publish RT Trainer v0.5 demo"
git push
```

På GitHub: Settings → Pages → Deploy from a branch → `main` → `/docs`.

Förväntad adress:

`https://perfect-speed.github.io/rt-trainer/`

## 4. Testpilot

Testa länken i Chrome/Edge och tillåt mikrofon. Testpiloten behöver inget OpenAI-konto och ser aldrig API-nyckeln.

## Säkerhet

- `server/.env` är fortsatt ignorerad av Git.
- Backend har request-rate-limit.
- OpenAI-krediter/budget bör hållas låga under pilotfasen.
