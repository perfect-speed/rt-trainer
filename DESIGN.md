# RT Trainer v0.12.0 — Scenario Foundation

## Design intent

The core boundary remains:

> World state owns truth. Dialogue logic may choose communicative intent. Phraseology owns normative wording. Speech owns voice and radio presentation, not operational values.

v0.12.0 shifts effort from speech micro-optimization to **stateful interaction**. The learner is no longer always replying to a pre-existing ATC prompt. In SCENARIO, the session begins in `awaiting initial call`; only a sufficiently identified call moves the world into established contact and causes ATC to respond.

## State represented in this slice

- learner callsign: SE-KQX
- ATS unit: Kalmar tower
- current frequency
- contact established / not established
- whether abbreviated callsign may be used
- operational values issued by ATC
- chronological radio-event history

## Non-goals

This version does not yet model channel occupancy, other aircraft, controller workload, mixed Swedish/English traffic, geographic movement, handover acceptance by another ATS unit, or a generative ATC policy. Those are intended to build on this stateful foundation rather than replace it.
