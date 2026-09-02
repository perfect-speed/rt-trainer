# RT Trainer v0.6.5 – Verified segmented speech

## Design goal

Keep the naturalness obtained with Realtime speech while enforcing stable,
repeatable Swedish radiotelephony content.

The governing rule remains:

> Scenario/world state owns reality. Generative AI owns expression.

v0.6.5 adds a second observation point after the generative speech model.

## Why this version exists

v0.6.4 showed that identical input could produce different audible output:
Q N Helge could vary, short final digits could disappear, and a segment could
sound truncated even when Realtime's own transcript looked complete.
Therefore the model's self-transcript is not sufficient evidence that the
actual audio contains the required phraseology.

## Architecture

```text
Scenario / world state
        |
        v
Deterministic RT formatter
        |
        v
Information groups
        |
        v
Realtime audio generation
        |
        +--> Realtime self-transcript guard
        |
        v
Generated PCM audio
        |
        v
Independent ASR verification
        |
        v
Deterministic token comparison
        |
        v
Accepted segment / retry
        |
        v
Concatenated ATC WAV
```

The independent verifier is deliberately downstream of audio generation. It
therefore measures what is present in the actual PCM rather than trusting the
generator's textual side channel.

## Stabilisation rules

1. Operational values are deterministic and never inferred by the speech model.
2. Each comma-delimited information group is generated separately.
3. Realtime's own transcript must match the deterministic speech script.
4. The generated audio is independently transcribed and must match the same script.
5. Rejected segments are regenerated, up to three attempts by default.
6. Segment tails are never trimmed; only leading silence may be reduced.
7. QNH is represented in the speech layer as `Q N Helge`, while the normative object remains `QNH`.
8. ASR normalisation may repair labels such as `Tune Helge` -> QNH, but may never repair a numerical value toward the expected answer.

## Diagnostic measurements

Every accepted/rejected segment logs expected script, Realtime transcript,
independent audio transcript, attempt, raw audio duration, post-leading-trim
duration and verification result. This gives us measurement points between
system blocks rather than only observing the final audible output.

## Experimental question

Can a generative audio model be used for natural prosody in a norm-governed
training system if deterministic content is checked independently after audio
generation?

Trade-off: v0.6.5 is expected to have more latency and API usage than v0.6.4.
That is acceptable at this prototype stage because phraseology stability is
the variable being tested.
