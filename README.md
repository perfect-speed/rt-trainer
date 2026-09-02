# RT Trainer v0.5 Demo

Första paketerade demoversionen för extern testpilot. Versionen bygger vidare på v0.4.5 och behåller den deterministiska valideringen, svensk radiotelefoni, svenskt bokstaveringsalfabet, PTT och ASR-kvalitetskontroll.

## Nytt i v0.5 Demo

- Ny startsida som tydligt markerar att detta är en testversion.
- Kort instruktion till testpiloten om PTT, svensk radiotelefoni och vad som är värdefullt att prova.
- Versionen är märkt **Demo v0.5** i appen.
- Slutvyn ber testpiloten särskilt notera ASR-misstolkningar, rimligheten i återkopplingen och onaturliga radiorepliker.
- Alla funktioner från v0.4.5 finns kvar, inklusive skillnaden mellan sakfel och fraseologivarning för banbeteckning.

## Viktig arkitektur för demo

Webbappen innehåller ingen OpenAI API-nyckel. Rösttranskribering går via backend. För lokal körning ligger nyckeln i `server/.env`, som är exkluderad från Git.

För en extern demo måste därför både Flutter-webbappen och backend publiceras. GitHub Pages räcker inte ensamt för röstfunktionen eftersom API-nyckeln aldrig får ligga i klienten.

## Lokal kontroll före publicering

I projektroten:

```powershell
flutter pub get
flutter test
```

Starta backend i separat terminal:

```powershell
cd server
npm install
npm start
```

Starta webbappen från projektroten:

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=http://localhost:8080
```

## Föreslagen testordning

1. Kör en korrekt återläsning med PTT.
2. Prova fel QNH eller transponderkod.
3. Prova rätt bana med icke-standardiserat tal, t.ex. `bana nitton`, och kontrollera att det blir fraseologivarning snarare än sakfel.
4. Prova svensk bokstavering av flera olika registreringar.
5. Kör scenariosekvensen och kontrollera att anropssignalens status följer med mellan stegen.

## Webbdemo

Se `WEB_DEPLOY.md`. Paketet innehåller `render.yaml` för backend och `deploy_web.ps1` för att bygga `docs/` till GitHub Pages. Backend stöder både GitHub Pages-origin och lokal testning via localhost:5000.
