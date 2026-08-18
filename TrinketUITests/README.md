# TrinketUITests

UI test conventions for Trinket. Agent workflow: `AGENTS.md`. Unit/UI overview: `Docs/Platform/Testing.md`. UI test selector constants: `Packages/TrinketFeatureSupport/.../AccessibilityID.swift`.

## Layout

| Area | Path | When |
|------|------|------|
| Smoke | `Smoke/`, `Smoke.xctestplan` | Local `test.sh smoke` and CI `smoke-full` (same three classes) |
| Exhaustive | `Play/`, `Collection/`, `Battle/` | Main CI (sharded); local only for targeted debugging |
| Integration | `Integration.xctestplan` (FullUI journey classes; smoke excluded) | Local `test.sh all`; explicit selection so new classes never silently run here |
| Performance | `Performance/`, `BattlePerformance.xctestplan` | Ad hoc `performance.sh` / `test.sh performance` when investigating performance; not CI or smoke |
| Support | `Support/Screens/` | Page objects (`PlayScreen`, `BattleScreen`, `TabBar`, …) |

Smoke is three launches: `SmokeShellTests` (one launch + tab bar for Play, Collection, Homestead, Options), `SmokeBattleTests` (battle chrome), `SmokeShopTests` (merchant controls). Bare `test.sh smoke` and `test.sh smoke-full` run the same plan; `test.sh smoke <Class>` filters it.

## Keep / drop

Keep/drop rubric: [Testing.md](../Docs/Platform/Testing.md). Prefer extending an existing keep method over a new class. Push rules/persistence to unit tests; UI proves the control path once.

## Launch args

Defined as `TestLaunchArg` in `Support/TrinketUITestCase.swift`; parsed by `AppEnvironment` (`LaunchScreen` in `Packages/TrinketAppState/Sources/TrinketAppState/App/AppTypes.swift`). Helpers: `allForScreen`, `allForTab`, `allForBattle`, `allForBattleVictory`, `allForMidBattle`, `allForShop`, `allForMystery`, `completedStages`.

**Default smoke args:** `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`.

**Additional:**

- `-launch-screen` (`hero:`, `companion:`, `item:`, `options`, `battle` → stage 1-1, `battle-victory` → stage 1-1 victory chrome without live ticks, `shop` → stage 2-4 merchant, `mystery` → stage 1-2 mystery, `labyrinth` / `labyrinth-map` → The Labyrinth map)
- `-selectedTab` (`play`, `collection`, `homestead`, `options`; `heroes`/`companions`/`inventory`/`search` → `.collection`)
- `-completed-stages`, `-battle-tick-interval`, `-starting-gold`
- `-disable-audio` (see `AppEnvironment.parse`)
- `-enable-frame-metrics` — DEBUG frame-pacing sampler plus `AccessibilityID.Debug.frameMetrics` and reset probes for the performance test matrix (not smoke)

Keep default launch args unless testing persistence. Prefer ids from `AccessibilityID` (e.g. `AccessibilityID.Play.stageNode(chapter:stage:)`, `AccessibilityID.Battle.hand`); assert with `assertExists`. UI tests tap tab **labels** (`"Homestead"`, `"Collection"`), not `AppTab` raw values.

## Speed

- Prefer `-launch-screen` / `-selectedTab` deep links; do not re-navigate a screen launch args already opened.
- Prefer one launch per class (`SeededSmokeUITestCase` or shared `setUp`) when methods share args; avoid `app.terminate()` + relaunch mid-suite unless args must change (then split classes).
- Prefer one launch + `TabBar` for round-trips that must exercise the tab bar itself.
- Prefer `-completed-stages` over scrolling Stage Select lists when seeding progress.
- Filter inventory/search with `replaceText` instead of grid scroll loops.
- Prefer `AccessibilityID` selectors over visible labels for primary CTAs (Aspect Begin Floor, Labyrinth node actions).
- Mid-battle exhaustive tests: enter via Play map (`play.openCampaign()` + `play.startBattle`) with `TestLaunchArg.allForMidBattle()` (60s ticks via `-battle-tick-interval`), not `-launch-screen battle` (ticks start at launch and race setup). Smoke battle is load-only deep-link; card play, hand-drag safety, and retreat live in `BattleFlowUITests` only. If Stage 1-1 already resolved, mid-battle methods `XCTSkip` instead of silently passing.
- `-launch-screen battle-victory` / `allForBattleVictory()` remain for the performance plan; exhaustive UI does not own victory chrome.
- Default assertion timeout is `TrinketUITestCase.defaultTimeout` (3s) for deep-linked screens.
- Accessibility audits are intentionally not part of the test suite. Keep UI assertions focused on stable test selectors and interaction outcomes — not display names, rarity labels, or scroll geometry unless that string is the product contract.
- UI tests run serially on a single simulator by default. Hotspots: `./Scripts/test-timing.sh report --top 30`.
