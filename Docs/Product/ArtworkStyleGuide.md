# Artwork production guide

This guide defines the visual language and production constraints for authored
and generated artwork. `ArtManifest/curated-assets.tsv` remains the source of truth for
asset IDs, kinds, source files, and focal points. Encoding settings belong to
`Scripts/prepare-art-assets.sh`; the [art pipeline](../../ArtManifest/README.md)
documents its formats and overrides.

## Art direction

Trinket is illustrated in a bold, high-energy anime style in the visual
tradition of modern kinetic action-anime studios: sharp, angular exaggeration,
with dynamic motion implied through sharply cut diagonal shadow shapes rather
than literal speed lines. Outlines are thick, confident black strokes of
varying weight. Shading is built from two to three hard-edged flat color steps
rather than gradients or soft painterly blending. Palettes favor saturated,
punchy colors with a high-contrast graphic-design sense of color blocking and
sharp graphic highlight flares. The environment carries the exact same bold
graphic treatment as foreground subjects, filling the full frame edge-to-edge.

Use lighting and palette to distinguish locations while strictly maintaining this
sharp graphic treatment:

| Setting | Palette and light |
|---|---|
| Forest | Saturated moss greens, deep umber, punchy amber gold; razor-sharp broken canopy light shapes |
| Dungeon or crypt | Deep slate, oxidized verdigris bronze, cold vivid cyan; high-contrast practical light cuts |
| Desert or ruins | Sun-bleached sand, terracotta, intense indigo shadow; hard-edged diagonal sun slabs |
| Tundra | Stark blue-gray, crisp bone white, electric violet; stark high-contrast snow light |
| Arcane space | Deep void black, luminous mineral magenta/cyan, sharp graphic energy accents |

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

### XP rewards

Standalone XP rewards use the two-book resource artwork and the same reward pill
as materials: an Experience caption, an increase-prefixed amount, and prepared artwork.
The books use blue-violet covers, bright ivory page blocks, and a simple silhouette
that remains readable at 20 and 36 points. XP bars, their gain labels, and character
progress totals retain their text treatment without an additional icon. XP artwork
is a presentation resource, not a Homestead currency.

## Prompt construction

Prompts should specify the subject, action, setting, lighting, palette,
composition, and exclusions. Describe what matters visually; avoid long prose
about unseen lore.

### Core style block

Every generation prompt incorporates Trinket's core style definition:

```text
Illustrated in a bold, high-energy anime style in the visual tradition of modern kinetic action-anime studios — sharp, angular exaggeration, dynamic motion implied through sharply cut diagonal shadow shapes rather than literal speed lines. Thick, confident black outlines of varying weight, with saturated, punchy colors and minimal color blending — shading built from two to three hard-edged flat color steps rather than gradients. Exaggerated dramatic perspective, sharp graphic highlight flares, and a high-contrast graphic color-blocking treatment rather than painterly subtlety. The environment itself carries the same bold graphic treatment as the subject, filling the full frame — not a character on a flat backdrop. No text, lettering, words, logos, signatures, watermarks, UI elements, borders, or cropped identifying features.
```

### Prompt templates by asset kind

#### 1. Characters, Heroes, Companions & Enemies (`combatant`)

```text
Illustrated in a bold, high-energy anime style in the visual tradition of modern kinetic action-anime studios — sharp, angular exaggeration in the pose, with dynamic motion implied through sharply cut diagonal shadow shapes rather than literal speed lines. Thick, confident black outlines of varying weight, with saturated, punchy colors and minimal color blending — shading built from two to three hard-edged flat color steps rather than gradients. Exaggerated dramatic perspective and slightly elongated limbs for maximum visual energy, sharp graphic highlight flares, and a high-contrast graphic color-blocking treatment. Dynamic [ACTION POSE / COMBAT STANCE] of [SUBJECT]. [DISTINCTIVE GEAR, WEAPON SILHOUETTE, ANATOMY, AND EXPRESSION DETAILS]. Set in [LOCATION / ENVIRONMENT], lit by [DRAMATIC DIRECTIONAL LIGHT SOURCE], using [PALETTE]. Strong readable silhouette, complete hands and weapon, environment to every edge filling the full frame — not a character on a flat backdrop. No text, lettering, logos, watermarks, UI elements, or borders.
```

#### 2. Abilities, Spells & Card Actions (`ability`, `talent`)

```text
Illustrated in a bold, high-energy anime style in the visual tradition of modern kinetic action-anime studios — sharp, angular graphic exaggeration with dynamic motion implied through sharply cut diagonal shadow shapes, impact angles, and geometric force vectors rather than literal speed lines. Thick, confident black outlines of varying weight, punchy saturated colors, and minimal color blending — shading built from two to three hard-edged flat color steps. Sharp graphic highlight flares and high-contrast color blocking. Decisive focal action depicting [SPELL / MARTIAL MANEUVER / MAGICAL BURST] of [ELEMENT / FORCE]. [DISTINCTIVE SHAPE, ENERGY ARCS, AND VALUE CONTRAST]. Lit by [INTENSE LUMINOUS SPELL GLOW], using [PALETTE]. High-impact composition, clean read at card size, environmental shockwave or backdrop filling the frame edge-to-edge. No text, lettering, logos, watermarks, UI frames, or borders.
```

#### 3. Items, Weapons, Armor & Artifacts (`item`)

```text
Illustrated in a bold, high-energy anime style in the visual tradition of modern kinetic action-anime studios — sharp, faceted angular shapes, graphic plane changes, and dynamic cast shadows rather than soft gradients. Thick, confident black outlines of varying weight, with saturated, punchy colors and minimal color blending — shading built from two to three hard-edged flat color steps. Sharp graphic specular highlight glints and crisp material delineation. Centered [ITEM / WEAPON / EQUIPMENT] showing [DISTINCTIVE CRAFTING, MATERIAL DETAILS, RUNES, WEAR, OR ELEMENTAL CHARGE]. Resting on or framed against [COMPLEMENTARY SUBDUED PHYSICAL SURFACE OR GRAPHIC BACKDROP], lit by [FOCUSED KEY LIGHT], using [PALETTE]. Clear iconic silhouette readable at inventory icon size, rarity conveyed through material quality and controlled graphic highlights rather than generic outer halos. Full canvas composition edge-to-edge. No text, lettering, logos, watermarks, or UI frames.
```

#### 4. Environments, Destinations & Chapter Backgrounds (`background`, `portrait_background`)

```text
Illustrated in a bold, high-energy anime style in the visual tradition of modern kinetic action-anime studios — dramatic wide-angle perspective, sharp architectural or topographical angles, layered atmospheric planes with sharply cut diagonal shadow shapes and sunbeams rather than hazy gradients. Thick, confident black outlines on structural edges, saturated punchy colors, and minimal blending — shading built from two to three hard-edged flat color steps across foreground, midground, and background layers. Sharp graphic edge highlights and high-contrast graphic color blocking. Scenic view of [DESTINATION / ENVIRONMENT / ARCHITECTURE]. Lit by [ATMOSPHERIC LIGHTING: TIME OF DAY / WEATHER / ENERGY CANOPY], using [PALETTE]. Broad value masses, layered scenic depth with no single face-sized focal subject, full-frame landscape or portrait composition tolerating fill crops across device viewports. No characters in the center foreground, no text, lettering, logos, watermarks, or UI borders.
```

#### 5. Mystery Events & Encounters (`encounter`)

```text
Illustrated in a bold, high-energy anime style in the visual tradition of modern kinetic action-anime studios — dramatic atmospheric storytelling, sharp graphic contrast, deep cut shadow planes, and angular focal elements. Thick, confident black outlines of varying weight, punchy saturated colors, and minimal color blending — two to three hard-edged flat color steps. Sharp graphic specular flares and high-contrast color blocking. Atmospheric encounter scene depicting [DISCOVERABLE FOCAL SUBJECT / SHRINE / WANDERER / DILEMMA] within [ENVIRONMENT]. Lit by [MOODY / DAPPLED / UNNATURAL LIGHT SOURCE], using [PALETTE]. Environmental mystery with a clear discoverable focal object and a reserved quiet composition area for text overlays; full frame edge-to-edge. No text, lettering, logos, watermarks, or UI frames.
```

#### 6. Resources & Curated Icons (`resource`, `slot_background`)

```text
Illustrated in a bold, high-energy anime style in the visual tradition of modern kinetic action-anime studios — compact, faceted silhouette, crisp angular planes, and bold graphic highlights. Thick, confident dark outlines, saturated punchy colors, and two to three hard-edged flat color steps with zero gradients or soft blending. [RESOURCE OBJECT / ICONIC SHAPE], [KEY MATERIAL AND COLOR DETAILS]. Simple centered silhouette filling 85-90 percent of the frame, extremely limited internal detail, readable down to 20x20 and 36x36 points. Lit by [CLEAN HIGH-ANGLE LIGHT], using [PALETTE]. Isolated on a clean background or transparent alpha with no muddy shadows. No text, lettering, logos, watermarks, or UI borders.
```

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
