# RT Trainer v0.12.1 — Departure State Machine

Scenario mode now models a departure as operational state rather than a scripted list of readbacks.

States: contact → taxi request → taxi clearance/readback → compressed taxi → holding point → ready report → line-up clearance/readback → compressed line-up → ready-for-departure report → take-off clearance/readback → compressed departure.

Principles:
- Pilot initiates when the operational situation requires a pilot call.
- ATC responds from world state; it does not advance merely because a drill card was completed.
- Radio exchanges run at normal time. Non-communicative movement is time-compressed.
- The visual aircraft position and radio logic are driven by the same departure state.
- No premature handoff to Sweden Control is included in this slice.
- OpenAI v0.9.2 radio-DSP speech remains the stable speech baseline.
