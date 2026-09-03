# RT Trainer v0.11.0 — Explicit prosodic boundary control

## Hypothesis

The remaining speech issue is primarily excessive phrase-boundary strength/timing inside familiar Swedish RT chunks, not pronunciation identity. Explicit SSML timing should therefore improve grouping more reliably than prompt engineering or orthographic hyphenation.

## Frozen layers

```text
AtcMessage / world truth
  -> deterministic Swedish phraseology
  -> [experimental speech layer]
  -> frozen v0.9 VHF radio DSP
  -> learner
```

No scenario values, normative wording, validator rules, learner ASR behavior, or radio-channel DSP coefficients are intentionally changed in v0.11.0.

## Experimental conditions

1. **Azure explicit**: `sv-SE-MattiasNeural`, explicit 90 ms SSML `<break>` inside the first callsign spelling group and inside `Q N Helge`; a modest +4% rate is scoped to those chunks.
2. **Azure plain control**: same Azure voice and same deterministic spoken script, but no internal prosodic SSML control.
3. **v0.9.2 baseline**: existing OpenAI `gpt-4o-mini-tts` pronunciation-chunk path.

All three are processed through the same frozen v0.9 DSP before playback. Frontend and backend caches remain condition-specific so `LYSSNA IGEN` replays the exact accepted waveform.

## Decision rule

The primary comparison is Azure explicit vs Azure plain. If explicit control clearly reduces the Q→N gap and improves callsign grouping without reducing post-DSP intelligibility, the architecture has gained a useful controllable timing layer. If the two Azure conditions are essentially indistinguishable, documented SSML timing is not sufficiently load-bearing for this use case and we should not continue tuning arbitrary break values indefinitely.

The v0.9.2 baseline remains useful for judging whether an Azure gain in control comes with an unacceptable loss in generic voice quality.
