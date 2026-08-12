# Artwork production guide

This guide defines the visual language and production constraints for authored
and generated artwork. `ArtManifest/curated-assets.tsv` remains the source of truth for
asset IDs, kinds, source files, focal points, and processing settings.

## Art direction

Trinket uses painterly, cinematic fantasy illustration with clear silhouettes,
tactile materials, atmospheric depth, and restrained magical effects. The
world should feel dangerous but inviting: lived-in rather than grim, elegant
rather than ornate, and colorful without becoming glossy or cartoonish.

Use lighting and palette to distinguish locations instead of forcing every
image into the same golden-hour forest treatment:

| Setting | Palette and light |
|---|---|
| Forest | Moss, umber, muted gold; broken canopy light and mist |
| Dungeon or crypt | Slate, oxidized bronze, cold blue; narrow practical light |
| Desert or ruins | Sand, terracotta, indigo; hard sun and cool shadow |
| Tundra | Blue-gray, bone, desaturated violet; diffuse snow light |
| Arcane space | Near-black, mineral color, one controlled luminous accent |

## Non-negotiable delivery constraints

- Do not include words, lettering, UI frames, logos, signatures, or watermarks.
- Keep the important subject inside the crop-safe region. Do not clip faces,
  hands, weapons, or identifying equipment unless the composition calls for a
  deliberate close-up.
- Make the silhouette and primary action readable at card size. Detail should
  reward enlargement, not carry the meaning by itself.
- Preserve visual room for UI overlays. Avoid bright high-frequency detail
  beneath expected titles, resource labels, and bottom scrims.
- Use one dominant focal point and a clear foreground/midground/background
  hierarchy. Magical effects support the subject rather than obscure it.
- Record provenance and usage rights before adding a source. Never treat an AI
  provider's output or a discovered image as automatically cleared for use.
- Deliver the uncropped source at the highest practical resolution. Let the
  asset pipeline produce shipping crops and renditions.

## Composition by asset kind

| Kind | Composition |
|---|---|
| Combatant or companion | Three-quarter or action pose, readable face and hands, complete weapon silhouette, environmental context to every edge |
| Enemy | Strong species/class silhouette and attack intent; leave enough surrounding environment for alternate crops |
| Ability | One decisive action, spell, or object; immediate value contrast; avoid a generic standing portrait |
| Item or equipment | One centered, identifiable object on a subdued physical surface; rarity comes from material and controlled light, not a colored halo alone |
| Encounter or event | Environmental mystery with a discoverable focal object; reserve a quiet overlay region identified by the consuming screen |
| Background | Layered depth, broad value masses, no single face-sized focal subject; tolerate fill crops across device sizes |
| Resource or icon-like art | Simple centered silhouette, limited internal detail, transparent or quiet background as required by the manifest kind |

Focal-point metadata should identify the semantic subject, not compensate for a
poor source composition. Preview every generated crop in its real UI before
accepting it.

## Prompt construction

Prompts should specify the subject, action, setting, lighting, palette,
composition, and exclusions. Describe what matters visually; avoid long prose
about unseen lore.

```text
Painterly cinematic fantasy illustration of [SUBJECT] [ACTION].
[DISTINCTIVE SHAPE, MATERIAL, AND COLOR DETAILS].
Set in [LOCATION], lit by [LIGHT SOURCE], using [PALETTE].
[SHOT AND COMPOSITION], clear silhouette, layered atmospheric depth,
tactile materials, restrained magical effects, environment to every edge.
No text, lettering, logo, watermark, border, UI, or cropped identifying features.
```

For character art, add only the anatomy, expression, equipment, and pose needed
to preserve identity. For event art, describe the clue or choice the player must
notice. For items, describe construction and wear rather than requesting a
generic rarity glow.

## Review checklist

Before adding or replacing a source:

1. Confirm the image fits its chapter, asset kind, and gameplay meaning.
2. Inspect anatomy, perspective, repeated details, illegible pseudo-text, and
   accidental signatures at full resolution.
3. Check silhouette and contrast at the smallest shipping presentation.
4. Preview all pipeline crops and adjust manifest focal points if necessary.
5. Record provenance and license evidence outside generated output.
6. Run `./Scripts/generate.sh --assets`, review the diff and memory report, then
   use the path-scoped handoff route from `Scripts/README.md`.

Intentional variation is desirable. Repetition of the same pose, rim light,
fog, pedestal, or glow across a set is a defect even when each image is
individually attractive.
