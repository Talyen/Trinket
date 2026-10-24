# Screenshot-guided Homestead mockups

ImageGen concepts from October 17, 2026, using existing Trinket screenshots and
artwork. [Library.md](../Library.md) owns shipping behavior. These images are design
references, not production assets or evidence of the implemented UI. Selected
historical prompts and the full generation record remain in Git history.

## Current refined boards

| Board | Depicted flow | Selected generated output |
|---|---|---|
| [Library / Bestiary](library-bestiary-v4.png) | Artwork-only landscape gallery, colored discovered enemies and disabled grayscale unknowns | `exec-cf49fdb5-0bd4-40fb-a61e-f5f14450ef7e.png` |
| [Research browser](research-browser-v4.png) | Portrait reward illustrations, compact project rows and small objective marks | `exec-71248663-cda3-483e-95a7-01bd9ba6cee2.png` |
| [Research detail](research-detail-v4.png) | Portrait recipe reward and three landscape defeat objectives, source-guidance row superseded and excluded from implementation | `exec-ebc97aed-3b7b-42d5-b27e-e68fd9afc5b1.png` |
| [Archery](archery-crafting-v3.png) | Portrait recipe cards and preview; one prominent Craft action | `exec-92d83b0d-5f7a-437b-b4e9-169f05b3c354.png` |

The boards depict independent example saves. Retain earlier board files used as
generation inputs or link targets; the selected boards do not override current policy.

## Actual screenshot references

| Preserved reference | Role |
|---|---|
| [Existing Forge, German](references/existing-forge-de.png) | Building title, backdrop, native sheet, equipment preview and material costs |
| [Existing Collection](references/existing-collection.png) | Dark browsing surface, cards, text roles and spacing |
| [Existing Homestead](references/existing-homestead.png) | Building hierarchy, resource artwork and native controls |

Original October 15–16 captures are preserved byte-for-byte. Ignore incidental
simulator overlays; these establish visual context, not current-main verification.

## Existing artwork inputs

Inputs resolve through [curated-assets.tsv](../../../ArtManifest/curated-assets.tsv):
Library/Archery Range portraits; landscape Slime, Goblin and The Blight Treant;
and Basic Shortbow, Longbow, Quiver and Crossbow portraits. Source masters remain
in repository `AssetSources/`; production uses prepared ArtCatalog assets, never generated
crops. Complete input order and source selections remain in this file's Git history.

## Visual review and implementation corrections

Keep these distinctions when using the boards:

- Bestiary has artwork only. Color means encountered and inspectable; grayscale
  means undiscovered and disabled. Research's separate defeat checks do not change
  that meaning. Static images cannot establish hit testing, unlocks or return state.
- Research uses compact portrait rewards, at most three independently completable
  objectives, and inspectable completed projects. The user rejected the depicted
  **Where to find** row. Historical Companion Chronicles/Spire Records examples do
  not add active projects; [Library](../Library.md) owns the current catalog contract.
- Use actual 3:4 equipment and selected landscape enemy framing. Wrap required
  objective names at larger text sizes. Generated crops, type, icons and dimensions
  are approximations; no raster measurement establishes shipping geometry.
- Archery v3 has inaccurate browser ordering and omits the in-sheet Back despite
  its prompt. Follow the recipe catalog and native sheet navigation. The illustrated
  48 Wood / 24 Iron / 8 Herbs price is a proposal, not balance evidence.
- Preserve readable unlock/cost constraints, native hit areas and the real resource
  assets. Review the shipping flow under the [visual gate](../../Platform/Verification.md#visual-completion-gate),
  including stale requests, reset, dismissal and return position.
