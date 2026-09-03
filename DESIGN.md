# RT Trainer v0.11.1 — Selective callsign flow

## Observation behind the change

Listening tests of v0.11.0 found a clearer improvement for spelled aircraft registrations (notably SE-MBN), but no clear improvement for Q N Helge.

## Experimental change

FLOW v0.11.1 therefore applies local prosodic treatment only to the leading spelled callsign. The remainder of the transmission is synthesized through the frozen v0.9.2 baseline function. This means Q N Helge is no longer separately accelerated or independently segmented by the candidate path.

The candidate pipeline is:

1. Deterministic Swedish RT script.
2. Detect leading spelled callsign.
3. Synthesize that callsign as one compact identity group at the v0.11 callsign speed.
4. Synthesize the remainder with the frozen v0.9.2 baseline pronunciation-chunking path.
5. Join with the existing short inter-group gap.
6. Apply the unchanged v0.9 VHF radio DSP to the complete PCM stream.

No operational values, phraseology rules, ASR validation rules or radio DSP coefficients are intentionally changed.
