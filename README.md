# RT Trainer v0.6.9 – Prosodic stability

v0.6.9 keeps the v0.6.7 resilient hybrid speech architecture and stabilises
segment endings and within-group rhythm. The goal is to retain the natural
Realtime voice while reducing the intermittent half-spoken final digit/word
heard in QNH and transponder groups, and reducing slow/over-emphasised spelling
words such as `Martin`.

Speech path:

```text
normative scenario
  -> deterministic Swedish RT speech script
  -> segmented Realtime generation
  -> transcript + independent audio verification
  -> acoustic tail check
  -> retry if content/tail is unsafe
  -> short deterministic tail padding
  -> concatenated WAV
  -> deterministic TTS fallback if Realtime cannot be accepted
```

### v0.6.9 changes

- Segment-specific prosody instructions:
  - callsigns: even compact rhythm; no spelling word may be stretched;
  - QNH: compact radio group, not slow dictation;
  - transponder: four digits as one rhythmic group;
  - runway/frequency: concise Swedish RT cadence.
- Realtime is explicitly instructed to complete the last token and leave a
  short acoustic pause before ending the segment.
- A waveform endpoint guard logs RMS/peak energy in the final 55 ms and retries
  a segment that still appears acoustically active at the buffer edge.
- Accepted segments receive 120 ms deterministic tail padding. The extra join
  gap is reduced to 30 ms, giving protection against clipped endings without a
  large artificial pause between information groups.
- The deterministic TTS fallback now retries once and appends a safe audio tail,
  preserving the v0.6.7 rule that a speech-guard rejection must not by itself
  result in silence.

The operational content remains locked by the deterministic scenario and
validator. Prosody may vary; runway, QNH, transponder, frequency and callsign
content may not.
