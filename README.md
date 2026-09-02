# RT Trainer v0.6.7 – Resilient hybrid speech

v0.6.7 keeps the segmented Realtime speech architecture from v0.6.5, but
changes the independent audio verifier. The verifier is now domain-aware
without receiving the expected callsign, runway, QNH, transponder code or
frequency as transcription hints.

Speech path:

```text
normative scenario
  -> deterministic Swedish RT speech script
  -> segmented Realtime speech generation
  -> Realtime transcript guard
  -> independent RT-aware ASR of generated PCM
  -> deterministic comparison against the locked script
  -> accepted segment / retry
  -> concatenated WAV to Flutter
```

The verification ASR defaults to `gpt-transcribe`. Its prompt contains only
generic Swedish radiotelephony vocabulary and the *type* of information group.
For example, a callsign segment gets the Swedish spelling alphabet as vocabulary
support, but not `SE-KQX` as a hint. A QNH segment gets generic guidance about
`Q N Helge`, but not the pressure value.

After transcription, the deterministic verifier normalises a small set of
known ASR confusions such as `Sigrid` -> `Sigurd`, `Kvintus` -> `Qvintus`, and
(in callsign-only context) `sex`/`söks` -> `Xerxes`. The final comparison is
still made against the locked deterministic script. Numerical values remain
strict: no wrong runway, QNH, transponder code or frequency is repaired toward
the expected answer.

Render diagnostics include segment type, expected speech script, Realtime
transcript, independent verification transcript, durations, attempt number and
verification result.

This version is intended to reduce false 502 rejections caused by the verifier
mishearing Swedish spelling words while retaining the independent audio guard.
