# RT Trainer – design principles (v0.5.5)

## Core principle

> **Stringens i reglerna – realism i uttrycket – progression i komplexiteten.**

The scenario/world model owns operational truth. The generative speech layer owns expression, but may not alter operational values.

## Prosodic grouping

Radiotelephony is not perceived as a flat sequence of equally separated words. Operational information is normally delivered in perceptual chunks. In the current prototype the important groups include:

- callsign
- runway
- QNH
- transponder
- frequency

The speech layer should therefore use two different temporal relationships:

1. **Within-group spacing:** very short. The items belong together perceptually.
2. **Between-group spacing:** short but clearly larger. The listener can separate one operational item from the next.

Examples:

- `Q N Helge + pressure digits` is one QNH group.
- `transponder + four digits` is another group.
- a full Swedish callsign is one rhythmic identity group, not five isolated spelling words.

This is not cosmetic. For novice training it affects working-memory load, segmentation of information and the perceived authenticity of the task. It is therefore part of the training design and a candidate variable for later empirical evaluation.

## Early training

Early drills remain comparatively stringent in required information and phraseology while the ATC presentation should still sound natural. Internal order among mandatory readback items is not treated as a hard semantic error merely because, for example, QNH and transponder are reversed. Callsign-final can remain a pedagogical convention in the introductory drill layer.
