# RT Trainer v0.12.1

## Departure State Machine

This version turns SCENARIO into a small operational departure sequence at Kalmar rather than a disguised readback drill.

Test flow:
1. Establish contact: “Kalmartornet, SE-KQX, god middag.”
2. After ATC answers, request taxi.
3. Read back taxi clearance.
4. Aircraft moves rapidly to holding point (compressed event time).
5. Pilot reports ready.
6. Read back line-up clearance; aircraft moves onto runway.
7. Pilot reports ready for departure.
8. Read back take-off clearance; aircraft starts/departs.

The visual panel follows the same state machine. Radio itself is not accelerated. There is deliberately no automatic Sweden Control handoff yet.

Speech baseline: OpenAI v0.9.2 + existing radio DSP.
