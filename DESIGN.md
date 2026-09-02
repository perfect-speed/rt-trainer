# RT Trainer – design principles (v0.5.2)

## Governing principle

**Stringens i reglerna – realism i uttrycket – progression i komplexiteten.**

The trainer deliberately separates operational truth from presentation:

1. **Scenario/world state owns reality.** Runway, QNH, transponder, frequency,
   callsign, service and authority are explicit data and are not invented by TTS.
2. **Deterministic validation owns normative assessment.** Safety-relevant and
   procedural facts are checked independently of generative wording.
3. **Speech presentation owns realism.** A deterministic Swedish RT formatter
   converts normative text to a pronunciation script (for example `QNH 1009`
   becomes `ku en hå ett nolla nolla nia`) before TTS renders it naturally.
4. **Generative AI may own expression, not operational truth.** Later versions
   may vary natural ATC wording and prosody, but only inside constraints supplied
   by the scenario engine.

## Early training

Early exercises should use consistent, relatively stringent phraseology while
ATC still sounds natural. The learner should struggle with the intended RT task,
not with an artificial textbook voice.

## Later progression

Later scenarios may add realistic variation, tempo, workload, traffic and
compressed everyday radio language. Assessment can distinguish semantic errors,
phraseology warnings and acceptable operational variation.
