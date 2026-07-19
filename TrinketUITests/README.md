# TrinketUITests

UI test conventions for Trinket. Agent workflow: `AGENTS.md`. Unit/UI overview: `Docs/Platform/Testing.md`. UI test selector constants: `Trinket/Shared/AccessibilityID.swift`.

## Layout

| Area | Path | When |
|------|------|------|
| Quick smoke | `QuickSmoke.xctestplan` (`SmokeHomesteadTests`) | Local / agents (`test.sh smoke`) |
| Full smoke | `Smoke/`, `Smoke.xctestplan` | CI / PR (`test.sh smoke-full`); local only when debugging |
| Exhaustive | `Play/`, `Collection/`, `Battle/` | Pre-merge (`test.sh ui` / `test-deploy.sh`) |
| Performance | `Performance/`, `BattlePerformance.xctestplan` | Frame-pacing matrix (`performance.sh` / `test.sh performance`); not smoke |
| Support | `Support/Screens/` | Page objects (`PlayScreen`, `BattleScreen`, `TabBar`, …) |

Smoke classes are lean per-screen **shell** checks: one assertion theme per method; split at ~20 lines. Discover current smoke classes under `Smoke/` rather than hard-coding a count here. Bare `test.sh smoke` runs only the Homestead canary; `test.sh smoke <Class>` filters the full Smoke plan for iteration.

## Keep / drop (do not add)

Keep UI tests only for shell/entry, state-changing journeys, or one-owner safety invariants — see the rubric in `Docs/Platform/Testing.md`.

**Do not add:**

- Marketing/copy strings, nav titles, or “unexpected text” catalogs
- Layout/chrome mirrors (overscroll, vertical pull, inventory grid layout)
- Mid-battle multi-step detail marathons that race live ticks
- Duplicate coverage of the same interaction in both smoke and FullUI
- Negative “unimplemented mode” catalogs when a positive Campaign + Explore assert already covers the chooser

Prefer extending an existing keep method over a new class. Push rules/persistence to unit tests; UI proves the control path once.

## Launch args

Defined as `TestLaunchArg` in `Support/TrinketUITestCase.swift`; parsed by `AppEnvironment` (`LaunchScreen` in `AppTypes.swift`). Helpers: `allForScreen`, `allForTab`, `allForBattle`, `allForBattleVictory`, `allForMidBattle`, `allForShop`, `allForMystery`, `completedStages`.

**Default smoke args:** `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`.

**Additional:**

- `-launch-screen` (`hero:`, `companion:`, `item:`, `options`, `battle` → stage 1-1, `battle-victory` → stage 1-1 victory chrome without live ticks, `shop` → stage 2-4 merchant, `mystery` → stage 1-2 mystery, `labyrinth` / `labyrinth-map` → The Labyrinth map)
- `-selectedTab` (`play`, `collection`, `homestead`, `options`; `heroes`/`companions`/`inventory`/`search` → `.collection`)
- `-completed-stages`, `-map-scroll-target`, `-battle-tick-interval`
- `-disable-audio` (see `AppEnvironment.parse`)
- `-enable-frame-metrics` — DEBUG frame-pacing sampler plus `AccessibilityID.Debug.frameMetrics` and reset probes for the performance test matrix (not smoke)

Keep default launch args unless testing persistence. Prefer ids from `AccessibilityID` (e.g. `AccessibilityID.Play.stageNode(chapter:stage:)`, `AccessibilityID.Battle.hand`); assert with `assertExists`. UI tests tap tab **labels** (`"Homestead"`, `"Collection"`), not `AppTab` raw values.

## Speed

- Prefer `-launch-screen` / `-selectedTab` deep links; do not re-navigate a screen launch args already opened.
- Prefer one launch per class (`SeededSmokeUITestCase` or shared `setUp`) when methods share args; avoid `app.terminate()` + relaunch mid-suite unless args must change (then split classes).
- Prefer one launch + `TabBar` for round-trips that must exercise the tab bar itself.
- Avoid long Play-map scrolls; use `-completed-stages` or `-map-scroll-target`.
- Filter inventory/search with `replaceText` instead of grid scroll loops.
- Prefer `AccessibilityID` selectors over visible labels for primary CTAs (Aspect Begin Floor, Labyrinth node actions).
- Mid-battle exhaustive tests: enter via Play map (`play.openCampaign()` + `play.startBattle`) with `TestLaunchArg.allForMidBattle()` (3s ticks), not `-launch-screen battle` (ticks start at launch and race setup). Smoke battle is load-only deep-link; hand-drag safety lives in `BattleFlowUITests` only. If Stage 1-1 already resolved, mid-battle methods `XCTSkip` instead of silently passing.
- Victory outcome chrome: use `-launch-screen battle-victory` (or `allForBattleVictory()`); do not nest mid-battle side quests inside a live victory poll.
- Default assertion timeout is `TrinketUITestCase.defaultTimeout` (3s) for deep-linked screens.
- Accessibility audits are intentionally not part of the test suite. Keep UI assertions focused on stable test selectors and interaction outcomes — not display names, rarity labels, or scroll geometry unless that string is the product contract.
- UI tests run serially on a single simulator by default. Hotspots: `./Scripts/test-timing.sh report --top 30`.
