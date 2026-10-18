# Screenshot-guided Homestead mockups

These are **proposed UI**, generated with the built-in ImageGen tool on October
17, 2026. They combine existing Trinket screenshots as interface references and
existing selected game artwork as compositing references. They are not screenshots
of implemented features, production artwork, or native visual-test evidence.

The [Library and Archery contract](../Library.md) owns current behavior and scope. Exact generation and correction prompts are preserved in
[Prompts.md](Prompts.md). No CLI/API fallback or new art-generation pipeline was used.

## Current refined boards

| Board | Depicted flow | Selected generated output |
|---|---|---|
| [Library / Bestiary](library-bestiary-v4.png) | Artwork-only landscape gallery, colored discovered enemies and disabled grayscale unknowns | `exec-cf49fdb5-0bd4-40fb-a61e-f5f14450ef7e.png` |
| [Research browser](research-browser-v4.png) | Portrait reward illustrations, compact project rows and small objective marks | `exec-71248663-cda3-483e-95a7-01bd9ba6cee2.png` |
| [Research detail](research-detail-v4.png) | Portrait recipe reward and three landscape defeat objectives, source-guidance row superseded and excluded from implementation | `exec-ebc97aed-3b7b-42d5-b27e-e68fd9afc5b1.png` |
| [Archery](archery-crafting-v3.png) | Portrait recipe cards and preview; one prominent Craft action | `exec-92d83b0d-5f7a-437b-b4e9-169f05b3c354.png` |

All selected outputs are copied unchanged into this directory. Original generated
outputs remain in the task's Codex generated-images directory. The boards show
independent example states rather than one synchronized player save.

Earlier boards remain as generation inputs and preserve previous chat links:
[Library v1](library-guide.png), [Research v1](research-projects.png),
[Archery v1](archery-crafting.png), [Library v2](library-guide-v2.png),
[Research v2](research-projects-v2.png), [Archery v2](archery-crafting-v2.png),
[Library v3](library-bestiary-v3.png), and [Research v3](research-projects-v3.png).
Their superseded designs include an item archive, undiscovered disclosure,
Bestiary labels/status, inspection of unknown enemies, five-objective research
and the oversized text-only project presentation. Current intent follows the
current product contract. No original asset was overwritten.

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
| `combatant / slime`, `combatant / goblin`, `combatant / the_blight_treant` | Landscape Bestiary art and Research objective thumbnails |
| `item / shortbow-basic` | Recipe card, research reward and focused-preview base art |
| `item / longbow-basic`, `item / quiver-basic` | Standard crafting cards |
| `item / crossbow-basic` | Standard recipe art and the Arms and Armor reward thumbnail |

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

V4 Bestiary inputs, in order: Library v3, actual Forge, original landscape Slime,
original landscape Goblin. Research browser inputs: actual Collection, original
portrait Shortbow, Longbow, Crossbow. Research detail inputs: actual Collection,
original portrait Shortbow, original landscape Slime, Goblin, The Blight Treant.
The initial Research detail output was
`exec-04f9dd05-80c1-4f92-a3ad-8cb4690204ef.png`. A correction uses that output,
actual Collection, original Slime, Goblin, Treant, in order; it removes the phone
hardware, reduces the reward image and restores wider objective thumbnails.
The selected corrected output is in the table above. The unselected initial
render remains in Codex generated-images, not in the application or artwork catalog.
All artwork is already selected in the manifest. Each request stays within the
built-in tool's five-reference limit; no synthetic contact sheet or new art master.

## Visual review and implementation corrections

The Bestiary v4 board removes every enemy caption/status and shows color Slime
and grayscale Goblin together without reordering. Grayscale is the sole visible
discovery treatment. The written interaction contract disables that entry until
first encounter, then opens the same prepared combatant detail sheet used in
battle; no victory requirement or separate Bestiary detail page. Sheet reuse was
checked against `PlayBattleOverlay`, `CombatantDetailSheet` and
`CombatantDetailPane` source. Static images cannot prove this interaction.

Research browser v4 uses portrait recipe art, concise titles/reward names and
three small objective marks instead of large text rows/fractions. Completed
milestones have one line and a check/chevron; repeated archive subtitles are gone.
Research detail uses a portrait reward and three landscape enemy objectives,
removing the flavor paragraph, Reward/workshop labels and the long objective list.
The source-guidance row shown in this concept was subsequently removed by the
user; implementation contains no Where to find feature. All three objective enemies
in its example are discovered, so each is colored; the Treant's open completion
mark means not defeated, not undiscovered. Discovery and objective completion
must remain independent. Research objective names are intentional; only the
Bestiary gallery hides names.

Known concept-only deviations to resolve in shipping SwiftUI:

- ImageGen approximates dimensions. Use exact 3:4 portrait item layout and selected
  landscape enemy framing, including small thumbnails. Reuse real prepared artwork
  and native components rather than generated crops or measured raster coordinates.
- Research cards must wrap at larger text sizes instead of truncating required
  target names. Count/floor objectives and insufficient Library tiers are specified
  in the product contract; the examples show three enemy objectives and eligible tiers.
- Static mockups do not verify grayscale hit testing, accessibility activation,
  encounter-without-victory unlocks, sheet dismissal or return position. Check
  these in native implementation, including stale requests and reset.
- Archery's retained v3 browser fully shows the first two and clips a sample next
  row whose ordering is inaccurate. Shipping order is Shortbow, Longbow, Recurve
  Bow, Crossbow, Quiver, then Focused Recipes. Keep every recipe.
- Archery v3 restores Resources but still omits the in-sheet Back despite its
  prompt. Preserve the actual sheet Back; building Back is not a substitute.
- Completed projects remain inspectable. Unlock/cost constraints stay readable;
  source-location hints are excluded. Native hit areas remain unchanged.
- The recipe's 48 Wood / 24 Iron / 8 Herbs remains a proposed price, not balance proof.
- Gold accents, icons, type and small resource details may be approximated. Use the
  existing controls, symbols and resource assets in production. An omitted exterior
  concept caption does not make a generated image an implemented screenshot.

These limits call for native rendered review during implementation, not new art.
