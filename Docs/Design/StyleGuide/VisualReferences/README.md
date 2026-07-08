# Trinket Visual Style Guide References

These images are visual direction references for the app-wide chrome and design-system work. They are not implementation specs by themselves; token names, accessibility behavior, and SwiftUI component APIs should remain defined in code and docs.

**Note:** Reference PNG boards listed below are not committed to this repository. Store them alongside this README locally or in your design archive; `AppVisualFoundation.md` and `TrinketDesignSystem` source are authoritative for shipped behavior.

Durable implementation guidance lives in `Docs/Design/StyleGuide/AppVisualFoundation.md`.

## Boards

- `01-north-star-overview.png` — overall visual direction and design-system scope.
- `02-theme-presets.png` — archived exploratory board; not part of the shipped visual system.
- `03-surfaces-materials.png` — surface roles, material usage, states, and Reduce Transparency fallback direction.
- `04-elemental-atmosphere.png` — mechanic tinting, badges, glows, particles, and accessibility guardrails.
- `05-screen-fragments.png` — representative adoption across Play, Collection, Inventory/Search, Homestead, Battle, Rewards, Options, and sheets.

## v2 Game-Compatible Pass

The `v2/` folder refines the first pass against Trinket's current product structure and near-term presentation goals:

- Bottom tabs are Play, Collection, Homestead, and Options.
- Collection owns Heroes, Pets, and Inventory examples.
- Battle examples are 2D card-art based, with Enemy/Hero/Pet surfaces, anchored health bars, SwiftUI feedback, and no 3D battlefield or manual ability hotbar.
- Ultimate examples are full-screen Hero/Pet cast cinematics (9:16 video when available, card-art fallback otherwise), not 3D battle scenes. Skills use caster-anchored ability-art callouts, not full-screen cinematics.
- Keyword examples use the current `Keyword` set and feedback categories.

Prefer the v2 boards for implementation direction unless a newer pass supersedes them.

## Folder Convention

Keep exploratory/generated visual references in this folder using numbered filenames:

```text
NN-short-description.png
```

If a board becomes an implementation decision, summarize that decision in the relevant style-guide or design-system doc instead of relying on the image alone.
