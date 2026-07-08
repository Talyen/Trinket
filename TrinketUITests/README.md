# TrinketUITests

UI test conventions for Trinket. Agent workflow overview: `AGENTS.md`. Accessibility id constants: `Trinket/Shared/AccessibilityID.swift`.

## Layout

| Area | Path | When |
|------|------|------|
| Smoke | `Smoke/`, `Smoke.xctestplan` | Tab/screen edits, pre-push (`test.sh smoke`) |
| Exhaustive | `Play/`, `Collection/`, `Battle/`, `Search/` | Pre-merge (`test.sh ui` / `test-deploy.sh`) |
| Support | `Support/Screens/` | Page objects (`PlayScreen`, `BattleScreen`, `TabBar`, …) |

Smoke classes are lean per-screen checks: one assertion theme per method; split at ~20 lines. Discover current smoke classes under `Smoke/` rather than hard-coding a count here.

## Launch args

Defined as `TestLaunchArg` in `Support/TrinketUITestCase.swift`; parsed by `AppEnvironment` (`LaunchScreen` in `AppTypes.swift`). Helpers: `allForScreen`, `allForTab`, `allForBattle`, `completedStages`, `mapScrollTarget`.

**Default smoke args:** `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`.

**Additional:**

- `-launch-screen` (`hero:`, `pet:`, `item:`, `options`, `battle` → stage 1-1)
- `-selectedTab` (`play`, `collection`, `homestead`, `search`, `options`; `heroes`/`pets`/`inventory` → `.collection`)
- `-completed-stages`, `-map-scroll-target`, `-battle-tick-interval`
- `-disable-audio`, `-appearance` (see `AppEnvironment.parse`)

Keep default launch args unless testing persistence. Prefer ids from `AccessibilityID` (e.g. `AccessibilityID.Play.stageNode(chapter:stage:)`, `AccessibilityID.Battle.pauseButton`); assert with `assertExists`. UI tests tap tab **labels** (`"Homestead"`, `"Collection"`), not `AppTab` raw values.

## Speed

- Prefer `-launch-screen` / `-selectedTab` deep links; do not re-navigate a screen launch args already opened.
- Prefer one launch + `TabBar` for round-trips that must exercise the tab bar itself.
- Avoid long Play-map scrolls; use `-completed-stages` or `-map-scroll-target`.
- Filter inventory/search with `replaceText` instead of grid scroll loops.
- Mid-battle exhaustive tests: enter via Play map, not `-launch-screen battle` with very fast ticks.
- Keep victory waits in a dedicated method; do not nest mid-battle side quests inside a 60s victory poll.
- Default assertion timeout is `TrinketUITestCase.defaultTimeout` (3s) for deep-linked screens.
- UI tests run serially on a single simulator by default. Hotspots: `./Scripts/test-timing.sh report --top 30`.
