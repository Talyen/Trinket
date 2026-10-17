# Screenshot-guided Homestead mockups

These are **proposed UI**, generated with the built-in ImageGen tool on October
17, 2026. They combine existing Trinket screenshots as interface references and
existing selected game artwork as compositing references. They are not screenshots
of implemented features, production artwork, or native visual-test evidence.

The [design and implementation plan](../LibraryResearchArchery.md) is the behavior
and scope specification. Exact generation and correction prompts are preserved in
[Prompts.md](Prompts.md). No CLI/API fallback or new art-generation pipeline was used.

## Final boards

| Board | Depicted flow | Selected generated output |
|---|---|---|
| [Library / guide](library-guide.png) | Building activity rows and discovered/unknown creature cards | `exec-7e1cdd2a-360a-4485-b452-43f03fc47db2.png` |
| [Research](research-projects.png) | Project browser, automatic progress, objective checks and recipe reward | `exec-23f0862b-bad7-4fae-b40f-8fd5d782ac10.png` |
| [Archery](archery-crafting.png) | Existing building backdrop, craft browser and focused recipe cost preview | `exec-be63b7b2-c26c-4dde-bf3f-caabc947d783.png` |

All selected outputs are copied unchanged into this directory. Original generated
outputs remain in the task's Codex generated-images directory. Rejected initial
variants need not be kept in the repository. The boards show independent example
states rather than one synchronized player save.

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
| `portrait_background / library` | Library building and research header |
| `portrait_background / archeryRange` | Range building behind Craft sheet |
| `combatant / slime`, `combatant / goblin` | Field Guide cards; Slime also supplied to initial research generation |
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

## Visual review and implementation corrections

Inspected all three initial boards and both corrected outputs. The selected
boards communicate recognizable existing buildings/creatures/items, readable
research objectives, the recipe reward, and the existing Forge-like cost dock.
The research correction removes misleading Slime/Shortbow subject thumbnails
from unrelated projects, replacing them with native symbols. The Archery
correction makes Crossbow look available and uses its existing artwork.

Known concept-only deviations to resolve in shipping SwiftUI:

- Field Guide's generated serif heading must use the existing native browser
  typography. Building/cinematic art titles retain their established role.
- Library's XP benefit should be its own existing-style benefit panel, separate
  from Upgrade; the image visually groups them more closely.
- Some list/grid card proportions and sheet detents are compressed for the board.
  Actual views must follow the current Collection/Forge components and safe areas.
- Archery's browser is an illustrative excerpt. Shipping contains all five standard
  recipes, including Recurve Bow, in the written catalog order before Focused
  Recipes. Do not implement the image's `More recipes below` annotation as a
  special control or omit the fifth recipe.
- Research tier requirements, locked recipe requirements, empty/pending states,
  completed buildings and localization are specified in the plan, not exhaustively
  pictured here. Sample counts do not assert an actual game's progress.
- The preview's 48 Wood / 24 Iron / 8 Herbs is a proposed price, not balance proof.
- Gold outlines, SF-style icons, body fonts, herbs and other small details may be
  approximated by ImageGen. Reuse real controls and resource assets in production.

These deliberate limitations are reasons for a native rendered review during
implementation. They do not require generating new production artwork.
