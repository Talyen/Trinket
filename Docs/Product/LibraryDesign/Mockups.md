# Screenshot-guided Homestead mockups

These concept boards are design references, not production assets or verification
of the implemented UI. [Library](../Library.md) owns shipping behavior.

- [Library / Bestiary](library-bestiary-v4.png): artwork-only gallery.
- [Research browser](research-browser-v4.png): compact illustrated project rows.
- [Research detail](research-detail-v4.png): recipe reward and defeat objectives.
- [Archery](archery-crafting-v3.png): recipe cards and preview.

Existing [Forge](references/existing-forge-de.png),
[Collection](references/existing-collection.png), and
[Homestead](references/existing-homestead.png) screenshots show the visual context.
Production artwork is selected through [curated-assets.tsv](../../../ArtManifest/curated-assets.tsv).

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
