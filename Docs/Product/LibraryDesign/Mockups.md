# Screenshot-guided Homestead mockups

These are **proposed UI**, generated with the built-in ImageGen tool on October
17, 2026. They combine existing Trinket screenshots as interface references and
existing selected game artwork as compositing references. They are not screenshots
of implemented features, production artwork, or native visual-test evidence.

The [Library and Archery contract](../Library.md) owns current behavior and scope.
Selected generation prompts are retained in [Prompts.md](Prompts.md); earlier
iterations remain in Git history.

## Current refined boards

| Board | Depicted flow | Selected generated output |
|---|---|---|
| [Library / Bestiary](library-bestiary-v4.png) | Artwork-only landscape gallery, colored discovered enemies and disabled grayscale unknowns | `exec-cf49fdb5-0bd4-40fb-a61e-f5f14450ef7e.png` |
| [Research browser](research-browser-v4.png) | Portrait reward illustrations, compact project rows and small objective marks | `exec-71248663-cda3-483e-95a7-01bd9ba6cee2.png` |
| [Research detail](research-detail-v4.png) | Portrait recipe reward and three landscape defeat objectives, source-guidance row superseded and excluded from implementation | `exec-ebc97aed-3b7b-42d5-b27e-e68fd9afc5b1.png` |
| [Archery](archery-crafting-v3.png) | Portrait recipe cards and preview; one prominent Craft action | `exec-92d83b0d-5f7a-437b-b4e9-169f05b3c354.png` |

The boards depict independent example saves. Earlier board files remain available
as generation inputs and for existing links; current intent follows the product
contract.

## Actual screenshot references

| Preserved reference | Role |
|---|---|
| [Existing Forge, German](references/existing-forge-de.png) | Building title, backdrop, native sheet, equipment preview and material costs |
| [Existing Collection](references/existing-collection.png) | Dark browsing surface, cards, text roles and spacing |
| [Existing Homestead](references/existing-homestead.png) | Building hierarchy, resource artwork and native controls |

These October 15–16, 2026 captures preserve their original bytes, including
incidental simulator overlays. Ignore the overlays. They are visual references,
not verification of current main; original paths and checksums remain in Git history.

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

Selected prompt inputs, in order:

| Concept | Inputs |
|---|---|
| Bestiary v4 | [Library v3](library-bestiary-v3.png), actual Forge, original landscape Slime and Goblin |
| Research browser v4 | Actual Collection, original portrait Shortbow, Longbow and Crossbow |
| Research detail v4 | Actual Collection, original portrait Shortbow, original landscape Slime, Goblin and The Blight Treant |
| Research detail correction | Initial detail render, actual Collection, original Slime, Goblin and Treant |
| Archery v3 | [Archery v2](archery-crafting-v2.png), actual Forge, original portrait Shortbow |

The selected detail correction removes the phone hardware, reduces the reward
image and restores wider objectives. Each request used at most five references;
no new art master or synthetic contact sheet was introduced.

## Visual review and implementation corrections

The Bestiary v4 board removes every enemy caption/status and shows color Slime
and grayscale Goblin together without reordering. Grayscale is the sole visible
discovery treatment. The written interaction contract disables that entry until
first encounter, then opens the same prepared combatant detail sheet used in
battle; no victory requirement or separate Bestiary detail page. Static images
cannot prove this interaction.

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
