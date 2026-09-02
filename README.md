# RT Trainer v0.6.2 – Realtime voice prototype

This iteration changes the ATC speech architecture. It keeps all existing readback validation and Swedish ASR behaviour, but adds a Realtime audio path intended to recover the natural radio feel observed in the earlier Kalmar–Jönköping conversational prototype.

The default voice path uses OpenAI Realtime audio through the Node backend. The normative ATC text is passed directly to the Realtime model; the model may realize pronunciation and prosody but must not change any operational value. The previous v0.5.5 TTS path is retained as an A/B baseline and can be toggled in the radio panel.

New backend environment variables:

```text
OPENAI_REALTIME_MODEL=gpt-realtime-1.5
OPENAI_REALTIME_VOICE=marin
```

Existing `OPENAI_API_KEY` is reused. No API key is exposed to Flutter or GitHub Pages.

## First test after copying files

```powershell
flutter test
```

There are no new Flutter packages. The backend has one new Node dependency (`ws`), which Render installs automatically via `npm install` after push.

For local Flutter testing against Render:

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

Start with **RÖST · REALTIME**. Listen especially to SE-GLA, QNH 1018 and SE-RYD. Then toggle to **RÖST · TTS BAS** for an immediate baseline comparison.
