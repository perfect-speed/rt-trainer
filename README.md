# RT Trainer v0.6.3 – Segmented controlled speech

v0.6.3 is an architecture experiment. It keeps the deterministic scenario,
validator and Swedish ASR from v0.6.2, but changes how the Realtime voice is
generated.

Instead of asking the model to reproduce a complete ATC transmission in one
generation, the backend splits the already-fixed spoken script into
information groups, for example:

```text
Sigurd Erik Kalle Qvintus Xerxes
bana nolla ett
Q N Helge ett nolla ett sexa
transponder fyra tvåa femma femma
```

Each group is generated and content-checked separately. Only accepted groups
are concatenated into the WAV returned to Flutter. The hypothesis is that a
small generative task can preserve natural local prosody without letting the
model omit or add operational information.

The v0.5.5-style TTS path remains available as **RÖST · TTS BAS** for A/B
comparison.

## First test after copying files

```powershell
flutter test
```

There are no new Flutter packages. Render installs the existing Node backend
dependencies automatically after push.

For local Flutter testing against Render:

```powershell
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

v0.6.3 may have noticeably longer first-audio latency because the groups are
deliberately generated sequentially. For this iteration, evaluate three things
separately: exact phraseology/content, naturalness inside each group, and the
quality of the joins between groups.
