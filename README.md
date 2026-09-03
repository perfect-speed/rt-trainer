# RT Trainer v0.12.2 — Kalmar Scenario Corrections

This release keeps the v0.12.1 departure state machine and corrects three issues found in cockpit-style testing.

- Kalmar ground picture redrawn as a simplified AIP-based ESMQ layout: RWY 16/34, crossing RWY 05/23, Apron 1/2 and TWY A. The RWY 16 holding point is now visibly before the runway.
- Callsign state fixed: after ATC introduces `S-QX`, the scenario accepts both textual `S-QX` and spoken Swedish spelling `Sigurd Qvintus Xerxes`.
- ATC introduces the abbreviated callsign after contact is established instead of repeatedly using the full registration.
- Normal Swedish RT digit words are used in good radio conditions: noll, ett, två, tre, fyra, fem, sex, sju, åtta, nio.
- OpenAI v0.9.2 radio-DSP speech remains the frozen speech baseline. No Azure/prosody experiment is active.

The airport graphic is a training schematic, not a navigation chart.
