# RT Trainer v0.9.1 — Prosodic chunking experiment

## Question

Can we improve operational speech flow without giving any generative component authority over the operational content?

The user observed that v0.9 adds useful radio character, but `Q N Helge` can sound like `Q … N … Helge` and spelled registrations can sound like teaching dictation. In actual RT these are familiar lexical/prosodic units and are normally produced with more internal flow.

## Frozen baseline

The following are intentionally unchanged from v0.9.0:

1. deterministic Swedish RT script;
2. one full-utterance neural TTS call;
3. v0.9 VHF DSP;
4. clarified digit words;
5. frontend PTT, ASR and readback validation.

## Experimental change

Only the TTS prosodic instruction changes.

`Q N Helge` is treated as one cohesive prosodic chunk. The letters remain distinct and Q must remain Swedish Q, but there should be no pedagogical pause between Q, N and Helge.

A full Swedish-spelled callsign is also treated as one identity chunk: clear individual spelling words, but with continuous operational rhythm.

Pauses belong between information groups, not inside these established chunks.

## Hypothesis

**Correctness sits in the representation; naturalness can be improved through grouping and timing.**

## Failure criteria

The experiment fails if any of the following occurs:

- Q becomes K again;
- `Q N Helge` loses a component;
- callsign letters/words are lost or changed;
- extra lexical material such as `svara` returns;
- the speech sounds no more fluid, or becomes rushed/less intelligible.

If correctness remains stable and internal flow improves, prosodic grouping becomes an explicit layer in the architecture.
