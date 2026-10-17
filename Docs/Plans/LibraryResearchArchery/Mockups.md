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
| [Library / guide](library-guide-v2.png) | Shared activity group, separate benefits, discovered cards and collapsed unknown entries | `exec-5e825843-0d53-4071-bebf-3dfa0172160b.png` |
| [Research](research-projects-v2.png) | Plain native list, objective checks and one tappable recipe reward row | `exec-1660471c-fa29-48e7-b445-630dd3b7ca83.png` |
| [Archery](archery-crafting-v2.png) | Restrained browser rows, grouped guarantee and one prominent Craft action | `exec-c26558fb-5d28-416a-98cb-622fbb7ded35.png` |

All selected outputs are copied unchanged into this directory. Original generated
outputs remain in the task's Codex generated-images directory. Rejected initial
variants need not be kept in the repository. The boards show independent example
states rather than one synchronized player save.

The previous [Library](library-guide.png), [Research](research-projects.png), and
[Archery](archery-crafting.png) boards remain as exact editing inputs and preserve
the earlier chat's links. They are superseded for current layout intent; the
implementation plan embeds only v2. No original asset was overwritten.

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

The refinement pass edits those selected boards with the actual screenshots again:
Library and Archery each use their prior board plus Forge; Research uses its prior
board plus Collection. All new prompts are preserved in Prompts.md. No new game
painting or asset-library source was introduced.

## Visual review and implementation corrections

Inspected the initial/corrected boards and all three refined outputs. V2 removes
the building-entry counters, repeated Library heroes, research filters, decorative
project thumbnails, redundant View Recipe button and permanent explanatory text.
The Library benefit is now separate from Upgrade; unknown guide entries are a
single disclosure. Research is a plain native list and recipe rewards are rows.
Craft's guarantee/rarity copy is grouped with the item, and only Craft is emphasized.

Known concept-only deviations to resolve in shipping SwiftUI:

- Some list/grid card proportions and sheet detents are compressed for the board.
  Actual views must follow the current Collection/Forge components and safe areas.
- Archery's browser is an illustrative excerpt. Shipping contains all five standard
  recipes, including Recurve Bow, in the written catalog order before Focused
  Recipes. Do not omit the fifth recipe or copy the sample's shortened order.
- Preserve the actual Resources toolbar action on the building and the native
  in-sheet Back control on recipe preview. ImageGen omits some of these in the
  refined Archery board; the underlying building Back is not a substitute for
  returning from a recipe to the Craft browser.
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
