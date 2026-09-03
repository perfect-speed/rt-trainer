# RT Trainer v0.12.0 — Scenario Foundation

This version deliberately returns to the **v0.9.2 OpenAI speech baseline**. Azure and v0.11 prosody experiments are not part of the normal training path. The development focus moves from micro-tuning TTS to the first stateful RT scenario.

## What changes

- DRILL remains deterministic readback training.
- SCENARIO now starts with the **learner making the first call**. ATC does not transmit until the learner identifies the station, aircraft and intent.
- The scenario retains radio history and contact state across the sequence.
- ATC introduces an abbreviated callsign only after full callsign contact has been established.
- A typed taxi instruction (`taxiToHoldingPoint`) is added to `AtcMessage`; operational values remain deterministic.
- The existing v0.9.2 OpenAI TTS + VHF DSP baseline is kept unchanged as the speech reference.

## Scenario slice

1. Learner (SE-KQX) calls Kalmar tower and requests taxi/departure.
2. ATC responds with taxi to holding point runway 16, QNH 1016 and squawk 4255.
3. Learner reads back the operational values.
4. ATC may then use the abbreviated callsign S-QX and issue a new squawk.
5. The same radio history continues to a frequency change to Sweden Control 124.725.

This is intentionally a small end-to-end state-machine slice. It is not yet a full Kalmar–Jönköping flight, shared-frequency model or generative controller.

## Run

```powershell
flutter test
flutter run -d chrome --web-port 5000 --dart-define=RT_API_URL=https://rt-trainer-api.onrender.com
```

Backend health should report `version: 0.12.0`, `scenarioFoundation: true` and `speechDefault: openai-v0.9.2-stable-radio-dsp`.
