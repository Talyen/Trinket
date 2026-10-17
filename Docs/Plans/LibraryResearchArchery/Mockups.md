# Screenshot-guided Homestead mockups

These are **proposed UI**, generated with the built-in ImageGen tool on October
17, 2026. They combine existing Trinket screenshots as interface references and
existing selected game artwork as compositing references. They are not screenshots
of implemented features, production artwork, or native visual-test evidence.

The [design and implementation plan](../LibraryResearchArchery.md) is the behavior
and scope specification. Exact generation and correction prompts are preserved in
[Prompts.md](Prompts.md). No CLI/API fallback or new art-generation pipeline was used.

## Current refined boards

| Board | Depicted flow | Selected generated output |
|---|---|---|
| [Library / Bestiary](library-bestiary-v3.png) | Two Library activities; landscape enemies with undiscovered art in grayscale in the same list | `exec-3d7dd6f1-b484-4cd4-92c6-4ef77e61ecbe.png` |
| [Research](research-projects-v3.png) | No item-collection project; three Forest objectives and a portrait reward thumbnail | `exec-34cc417a-519d-45f9-b3f5-a579650dee1e.png` |
| [Archery](archery-crafting-v3.png) | Portrait recipe cards and preview; one prominent Craft action | `exec-92d83b0d-5f7a-437b-b4e9-169f05b3c354.png` |

All selected outputs are copied unchanged into this directory. Original generated
outputs remain in the task's Codex generated-images directory. The boards show
independent example states rather than one synchronized player save.

The initial [Library](library-guide.png), [Research](research-projects.png), and
[Archery](archery-crafting.png) boards and intermediate
[Library v2](library-guide-v2.png), [Research v2](research-projects-v2.png), and
[Archery v2](archery-crafting-v2.png) remain as exact editing inputs and preserve
previous chat links. Their item archive, undiscovered disclosure, five-objective
project and compressed artwork layouts are superseded. The implementation plan
embeds only v3. No original asset was overwritten.

## Actual screenshot references

Copies below preserve source bytes, including incidental simulator overlays.
Those overlays are not proposed game UI and must not be implemented.

| Preserved reference | Original local source | Role |
|---|---|---|
| [Existing Forge, German](references/existing-forge-de.png) | `/private/tmp/trinket-localization-ui-20261015/de-forge.png` | Actual building title, backdrop, native sheet, equipment preview and material-cost layout |
| [Existing Collection](references/existing-collection.png) | `/private/tmp/trinket-duo-finish-20261016/portrait-collection.png` | Actual dark browsing surface, illustrated cards, text roles and spacing |
| [Existing Homestead](references/existing-homestead.png) | `/private/tmp/trinket-duo-final-20261016/homestead-fill-open-portrait.png` | Actual building/art hierarchy, wallet/resource illustrations and native controls |

These are pre-existing captures from the named October 15/16 local artifact sets;
no new simulator run, build, or interaction test was performed for this planning
task. They establish visual references, not verification of today's exact main.

Reference SHA-256 checksums:

```text
existing-forge-de.png
05ce2e20f6a13282b480ac8beab37af7c62a3aa8f089d31675ea348327fcebd4
existing-collection.png
f21d2b2f882087f2f57a0ba558e04a1efb28cfc45ee634dd2d80b48da60bf17b
existing-homestead.png
f4c90768593ca633992235ea4203d28198d55ed791c274c56aace03bd4b06eb4
```

## Existing artwork inputs

Sources were inspected before generation and resolved through
[the curated art manifest](../../../ArtManifest/curated-assets.tsv). Source masters
live under the shared Asset Library; no master or asset-catalog file was edited.

| Manifest kind / ID | Role |
|---|---|
| `portrait_background / library` | Library building; research headers in superseded initial boards only |
| `portrait_background / archeryRange` | Range building behind Craft sheet |
| `combatant / slime`, `combatant / goblin` | Landscape Bestiary entries; Slime also supplied to initial research generation |
| `item / shortbow-basic` | Recipe card, research reward and focused-preview base art |
| `item / longbow-basic`, `item / quiver-basic` | Standard crafting cards |
| `item / crossbow-basic` | Correction replacing the initial misleading placeholder |

Raw portraits use the manifest-selected `Library - Portrait.jpeg` and
`Archery Range - Portrait.jpeg`; item inputs use their selected `- Basic.jpeg`
masters. Production must use existing prepared ArtCatalog references. ImageGen
may reinterpret edges, crops, typography and small details, so no generated crop
is an acceptable replacement for the actual game asset.

Input order is explicit in each original prompt. Library uses Forge, Collection,
Library, Slime, Goblin. Research uses Forge, Library, Shortbow, Slime, Homestead.
Archery uses Forge, Range, Shortbow, Longbow, Quiver. Research correction uses its
initial generated board; Archery correction uses its initial board plus Crossbow.

The refinement pass edits those selected boards with the actual screenshots again:
Library and Archery each use their prior board plus Forge; Research uses its prior
board plus Collection. All prompts are preserved in Prompts.md. No new game
painting or asset-library source was introduced.

V3 Library uses Library v2, actual Forge, original landscape Slime, original
landscape Goblin, in that order. V3 Research uses Research v2, actual Collection,
original portrait Shortbow. V3 Archery uses Archery v2, actual Forge, original
portrait Shortbow. These inputs correct the earlier board crops while retaining
the native screenshot references. Existing masters were inspected before editing.

## Visual review and implementation corrections

Inspected all three v3 outputs. Library now exposes Bestiary and Research only;
Trinkets/Uniques stay in Collection, with no parallel item archive. The Bestiary
shows colored Slime and grayscale Goblin landscape art together, named and
inspectable. There is no category switch or undiscovered disclosure. Research
removes Relic Curiosities, shows exactly three Forest targets (Slime, Goblin,
The Blight Treant), and uses a portrait Shortbow reward thumbnail. Archery's
standard recipe cards and preview use portrait item artwork. Earlier minimal
layout decisions remain: plain research list, one reward row, no repeated Library
hero, quiet utility typography and Craft as the only prominent primary action.

Known concept-only deviations to resolve in shipping SwiftUI:

- ImageGen approximates dimensions. Bestiary images are landscape but wider than
  the original approximately 4:3 masters; production must retain selected source
  framing. Every equipment image must use exact 3:4 portrait layout, including
  the smallest reward/focused-recipe thumbnail. Use real prepared artwork and
  native components rather than generated crops or measured raster coordinates.
- Archery's browser is an illustrative excerpt. Shipping contains all five standard
  recipes, including Recurve Bow, in the written catalog order before Focused
  Recipes. V3 fully shows the first two and clips the next row, whose sample
  ordering is inaccurate (Quiver precedes Recurve Bow). Use the plan's authored
  order, with Recurve Bow third, Crossbow fourth and Quiver fifth; never jump to
  Focused Recipes before all five standard recipes.
- Preserve the actual Resources toolbar action on the building and the native
  in-sheet Back control on recipe preview. V3 Archery restores Resources but still
  omits its in-sheet Back despite the prompt. The underlying building Back is not
  a substitute for returning from a recipe to the Craft browser.
- Completed research rows remain inspectable and expose a native navigation
  affordance; a completion check must not imply that the row stopped working.
- Research tier requirements, locked recipe requirements, empty/pending states,
  completed buildings and localization are specified in the plan, not exhaustively
  pictured here. Sample counts do not assert an actual game's progress.
- The preview's 48 Wood / 24 Iron / 8 Herbs is a proposed price, not balance proof.
- Gold outlines, SF-style icons, body fonts, herbs and other small details may be
  approximated by ImageGen. Reuse real controls and resource assets in production.

These deliberate limitations are reasons for a native rendered review during
implementation. They do not require generating new production artwork.
