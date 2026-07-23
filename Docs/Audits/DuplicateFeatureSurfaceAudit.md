# Duplicate Feature Surface Audit

**Goal:** Collapse near-duplicate SwiftUI product surfaces — copied hubs, encounter shells, detail panes, pickers, and summary grids — into one parameterized owner without inventing a new UI framework.

## Intent

Find all cohesive clusters of **confirmed** copy-paste feature surfaces and write a plan to collapse them under their existing owners (breaking into phases if the scope is large). Require three structural twins, or two with demonstrated drift/duplicate maintenance. A successful collapse removes the old paths and reduces net LOC/declarations; do not build a generic configuration surface for two callers.

## What counts as a duplicate surface

Duplicate surfaces look like parallel product screens that differ mainly by labels, catalogs, or bindings — not by interaction model.

| Tell | Why it is a finding |
|------|---------------------|
| Parallel `*HubView` / `*EncounterView` with the same section stack | Agents copied a shell instead of parameterizing mode/content |
| Near-identical detail / summary / picker layouts across tabs | Same grid, chrome, and empty states with tiny diffs |
| Repeated reward / outcome / artwork wrappers | Shell already exists (or should) under `Features/Shared` or DesignSystem |
| Same `GridItem` / card stack / sheet scaffolding in 3+ files | Layout ownership belongs in one helper, not N call sites |
| Diverged twins that used to match | Copy-paste drift — bugs get fixed in one sibling only |

**Not this audit:** single-file ceremony (`*Helper`, narrating comments) → InelegantSlop; raw Metrics/typography literals → AppleNativeUI; unused symbols → DeadCode; logic living in the wrong module → StateGravity.

## Hard stops

- Do not force unrelated product flows into one type (e.g. Battle hand vs Collection grid) just because both show cards.
- Do not move shared chrome into `Features/` when it already belongs in `TrinketDesignSystem`, or domain rules into views.
- Prefer the owning audit when the hit is primarily dead code, slop ceremony, token adoption, or state ownership.

## Confirm before fixing

1. **Structural twin:** same section order / chrome / interaction pattern across ≥3 call sites, or two call sites with demonstrated drift (not merely similar names).
2. **Maintenance cost:** a change would need to land in multiple siblings, or already has drifted.
3. **Safer shared shape:** one parameterized view or helper in the existing owner preserves behavior.
4. **Plan scope:** write a plan covering all identified clusters; if the scope across features is large, organize the plan into phases.

## Simplification order

1. **Delete** the weaker twin when one path is strictly redundant.
2. **Parameterize** in place under the existing feature folder; avoid generic config/`@ViewBuilder` APIs when a small concrete parameter is enough.
3. **Move** shared product UI into `Trinket/Shared/` or `Trinket/Features/Shared/` when ≥2 feature folders need it.
4. **Adopt** DesignSystem modifiers / Metrics for chrome duplication — route pure token work through AppleNativeUI when that is the whole fix.
5. **Propose** a larger shared shell or ownership move when local parameterization would leave the same twins nearby.

## Domain rules

Ownership follows [Architecture.md](../Platform/Architecture.md):

| Surface kind | Prefer owner |
|--------------|--------------|
| App-wide cards, detail panes, keyword text, AccessibilityID | `Trinket/Shared/` |
| Cross-Play-mode shells (reward reveal, shared encounter chrome) | `Trinket/Features/Shared/` or the dominant Play owner |
| Glass / surfaces / typography / Metrics | `TrinketDesignSystem` |
| Mode-specific content bindings | Stay in the feature folder; pass data into the shared shell |

Keep intentional product differences (mystery vs shop rules, labyrinth vs explore progression). Collapse only the **view scaffolding** and repeated presentation.

## Probe hints

- **Duplicated Card & Artwork Components:** Search for `Card` or `Artwork` struct definitions across `Trinket/Features/` and `Shared/`; compare `ItemCard`, `AbilityCard`, and `CombatantCard` for copy-pasted hover, border, or badge modifiers.
- **Empty State & Placeholder Duplication:** Search for `ContentUnavailableView` or custom empty-state card placeholders across `Collection/`, `Homestead/`, and `Play/`; collapse repeated empty-state wrappers into `Trinket/Shared/`.
- **Parallel Grid & Picker Scaffolding:** Compare `ItemViews.swift`, `CollectionCombatantGridView.swift`, `HomesteadCategoryView.swift`, and `BattlePartyInlinePicker.swift` for near-identical `LazyVGrid` and selection card wrappers.
- **Encounter & Mode Hub Scaffolding:** Search `Features/Play/` for parallel `*HubView` or `*EncounterView` files; verify whether section stacks can adopt `PlayModeHubScreen` or `EncounterReadingShell`.
