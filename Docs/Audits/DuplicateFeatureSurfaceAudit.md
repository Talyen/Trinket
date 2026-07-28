# Duplicate Feature Surface Audit

**Goal:** Collapse near-duplicate SwiftUI product surfaces — copied hubs, encounter shells, detail panes, pickers, and summary grids — into one parameterized owner without inventing a new UI framework.

## Intent

Collapse confirmed copy-paste feature surfaces under their existing owners. Require three structural twins, or two with demonstrated drift/duplicate maintenance. A successful collapse removes the old paths and reduces net LOC/declarations; do not build a generic configuration surface for two callers. Planning and phasing: [README.md](README.md).

## What counts as a duplicate surface

Duplicate surfaces look like parallel product screens that differ mainly by labels, catalogs, or bindings — not by interaction model.

| Tell | Why it is a finding |
|------|---------------------|
| Parallel hub / encounter shells with the same section stack | Agents copied a shell instead of parameterizing mode/content |
| Near-identical detail / summary / picker layouts across tabs | Same grid, chrome, and empty states with tiny diffs |
| Repeated reward / outcome / artwork wrappers | Shell already exists (or should) in `TrinketFeatureSupport` or DesignSystem |
| Same grid / card stack / sheet scaffolding in 3+ files | Layout ownership belongs in one helper, not N call sites |
| Diverged twins that used to match | Copy-paste drift — bugs get fixed in one sibling only |

**Not this audit:** single-file ceremony → InelegantSlop; raw Metrics/typography literals → AppleNativeUI; unused symbols → DeadCode; logic living in the wrong module → StateGravity.

## Hard stops

- Do not force unrelated product flows into one type (e.g. Battle hand vs Collection grid) just because both show cards.
- Do not move shared chrome into `Features/` when it already belongs in `TrinketDesignSystem`, or domain rules into views.
- Prefer the owning audit when the hit is primarily dead code, slop ceremony, token adoption, or state ownership.

## Evidence bar

Structural twin (same section order / chrome / interaction pattern across ≥3 call sites, or two with demonstrated drift) plus maintenance cost (a change would need to land in multiple siblings, or already has drifted), with a safer shared shape in an existing owner.

## Domain rules

Ownership follows [Architecture.md](../Platform/Architecture.md):

| Surface kind | Prefer owner |
|--------------|--------------|
| App-wide cards, detail panes, keyword text, AccessibilityID | `TrinketFeatureSupport` |
| Cross-Play-mode shells (reward reveal, shared encounter chrome) | `TrinketFeatureSupport` or the dominant Play owner |
| Glass / surfaces / typography / Metrics | `TrinketDesignSystem` |
| Mode-specific content bindings | Stay in the feature folder; pass data into the shared shell |

Keep intentional product differences (mystery vs shop rules, labyrinth vs explore progression). Collapse only the **view scaffolding** and repeated presentation. Prefer deleting a strictly redundant twin, then parameterizing in place, before proposing larger shared shells.
