# RT Trainer v0.6.5 – Verified segmented speech

v0.6.5 keeps the natural Realtime voice from the v0.6 branch, but adds an
independent verification pass over the audio that was actually generated.
The purpose is to improve repeatability without moving operational truth into
the generative model.

Speech path:

```text
normative scenario
  -> deterministic Swedish RT speech script
  -> segmented Realtime speech generation
  -> Realtime transcript guard
  -> independent ASR of the generated PCM audio
  -> deterministic content comparison
  -> concatenate accepted segments
  -> WAV to Flutter
```

The important change is the second guard. A Realtime response can report a
complete transcript even when the audio sounds truncated or different. v0.6.5
therefore transcribes the generated audio itself and only accepts a segment
when that independent transcript contains the same deterministic RT content.
A failed segment is regenerated, up to three attempts by default.

For diagnostics, Render logs now include for every segment:
- exact expected speech script
- Realtime's own transcript
- independent verification transcript
- raw and trimmed audio duration
- attempt number and accepted/rejected state

QNH remains normative as `QNH 1016`, while the isolated speech script now uses
`Q N Helge ett nolla ett sexa`. The voice instruction explicitly requests
Swedish Q and N pronunciation. The verifier accepts common ASR spelling such
as `Tune Helge` as a transcription artifact, but does not change the QNH value.

This version intentionally adds some latency and API cost. It is an experiment
in whether independent audio verification can preserve Realtime naturalness
while making phraseology substantially more reproducible.
