# RT Trainer v0.6.6 – RT-aware audio verification

## Design goal

Preserve the natural Realtime voice while making the downstream verifier aware
of Swedish radiotelephony vocabulary without leaking the answer into ASR.

> Scenario/world state owns reality. Generative AI owns expression.

## Why v0.6.6 exists

v0.6.5 demonstrated a second-model problem: Realtime could report the correct
spoken script while the independent ASR transcribed `Sigurd` as `Sigrid`,
`Qvintus` as `Kvintus`, or `Xerxes` as ordinary Swedish words. The guard then
rejected potentially correct audio. A second AI is not an oracle; its own error
model must be handled.

## Architecture

```text
Deterministic scenario
        |
        v
Locked Swedish RT script
        |
        v
Segmented Realtime audio
        |
        +--> Realtime self-transcript guard
        |
        v
Generated PCM
        |
        v
Independent RT-aware ASR
  generic vocabulary only
  no expected operational values
        |
        v
Domain-aware canonicalisation
        |
        v
Exact deterministic comparison
        |
        v
Accept / retry
```

## Verification rules

1. The ASR verifier is told the segment *type* but not its correct value.
2. Callsign verification receives the Swedish spelling alphabet as vocabulary support, not the expected registration.
3. QNH verification receives generic `Q N Helge` terminology but not the expected pressure.
4. Transponder, runway and frequency values remain exact after transcription.
5. A small, explicit alias table handles recurring ASR-only spelling confusions.
6. `sex`/`söks` may map to `Xerxes` only in a callsign-only segment; elsewhere `sex` remains digit 6.
7. The deterministic script remains the final source of truth.
8. Failed segments are regenerated up to three times by default.

## Research relevance

This version separates two uncertainties that are often conflated: uncertainty
in a generative speech model and uncertainty in the model used to verify it.
The verifier therefore receives domain vocabulary but not the correct answer.
That reduces verification error without allowing the verifier to simply infer
the expected output from context.
