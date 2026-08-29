---
type: execution-plan
status: complete
created: 2026-08-29
updated: 2026-08-29
expires: 2026-09-12
---

# LabyrinthClearedNodeRefresh — replace green check+green border with muted map + paper seal

## Objective
Make `cleared` hexes read as "visited parchment" — glance distinct from `locked` and `reachable`, without `success` green that competes with encounter tints and obscures art. Smallest diff that satisfies HIG simplicity/craft and Swift compositor rules.

## Context / Decision
Current `Trinket/Features/Play/Modes/LabyrinthMapClusterViews.swift:149-183` `LabyrinthMapNodeSeal` uses `TrinketDesign.Colors.success.opacity(0.55)` border + centered `Image(systemName:"checkmark")` in `success` `165-176`. Evaluated 5 options. Winner per `apple-design` `foundations + materials-and-depth + motion-and-gestures + performance-and-feedback`:

* **1 quiet cartography** — desaturate+scrim+thin ink stroke, recede to `scale 0.97`, no color pop.
* **2 small corner accessory** — 14pt `Overlay.paper` seal at `bottomTrailing` with monochrome `seal.fill` 8pt in `Overlay.ink` (not a 40pt center glyph). Chosen symbol `seal.fill`.
* **(+6 momentary settle)** — gold → ink stamp spring at the commit instant, then settles to 1+2. Celebration is motion, not persistent chrome.

Rejected: large center glyph, persistent green border, hollow emboss, lit inter-node trail (wayfinding win but out of scope).

## What it will look like
* **Reachable:** saturated art, 3pt `accent` stroke + existing pulse `reachablePulseOpacity:142` — only saturated thing on floor.
* **Cleared:** `saturation 0` + `opacity 0.72` + `Overlay.ink.opacity(0.32)` scrim; `LabyrinthHexagon:267` stroke `subtleStroke.opacity(0.55)` 1.5pt; shadow off; 14pt paper seal (paper disc 14pt, stroke 1pt `subtleStroke`, inner 7-8pt SF symbol `ink.opacity(0.65)`) inset 2pt bottomTrailing. At distance: dimmed hex + white pinprick. At lean-in: etched wax seal.
    * 14pt = points diameter — ~1/4 hex width (`LabyrinthHexMetrics:250` `radius*sqrt(3)` ~56pt). Not a cover.
* **Locked:** `opacity 0.42` + `subtleStroke` 2pt as today `162`. Hierarchy `locked < cleared < reachable` luminance.
* **On clear (+6):** `LabyrinthMapMotion.selection` `spring response 0.22 damping 1` `scale 1→1.08→0.97` + accent ring flash `0.72→0`, scrim+desat bleed 220ms, seal `scale 0.7→1`. Seated to quiet state.

Dark/light: scrim opacity same token adapts via `Overlay.ink`; paper seal stays legible over any `encounterBattle/Shop/Rest/Event` art (`LabyrinthMapPresentation.swift:47`).

## Scope
Touched: `LabyrinthMapClusterViews.swift` only. No save/migration, no `LabyrinthProgress` change (`LabyrinthMapPresentation+State.swift:22` stays).
Untouched: generator, `LabyrinthProgress:149`, inspector, floor motion, budgets, VoiceOver branches per `accessibility.md` (no `DifferentiateWithoutColor`).

## Plan
- [x] Record baseline — green check at `ClusterViews:165-169`, success border `175-182`.
- [x] Implement `LabyrinthMapNodeSeal` refresh: remove centered check, add scrim/saturation/opacity, thin ink stroke for cleared, 14pt paper seal corner, cleared scale 0.97, clear-settle spring from reachable→cleared.
- [x] No new tests — state mapping unchanged (`StageMapPresentationTests:181,208`); visual-only.
- [x] Verify `./Scripts/handoff.sh --isolate --paths Trinket/Features/Play/Modes/LabyrinthMapClusterViews.swift Packages/TrinketFeatureSupport` — style pass, TrinketFeatureSupport 44 passed, smoke wall 48s
- [x] Mark complete, move to `Docs/Plans/Archived/`.

## Notes
Keep durable policy in canonical owner. On complete set `status: complete` and move to `Archived/`.
