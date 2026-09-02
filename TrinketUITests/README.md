# TrinketUITests

UI test mechanics for Trinket. Agent workflow: `AGENTS.md`. Semantic test
ownership and keep/drop rules: [`Docs/Platform/Testing.md`](../Docs/Platform/Testing.md).
UI selector constants live in `Packages/TrinketFeatureSupport`.

## Layout

| Area | Path | When |
|------|------|------|
| Smoke | `Smoke/` sources; `Smoke.xctestplan` at repo root | Local and CI `test.sh smoke` (registry-defined classes); CI shards shell vs play |
| Exhaustive | `Play/`, `Collection/`, `Battle/` | Main CI (sharded by feature, homestead detail separate); local only for targeted debugging |
| Performance | `Performance/`, `BattlePerformance.xctestplan` (repo root) | Ad hoc `performance.sh` / `test.sh performance` when investigating performance; not CI or smoke |
| Support | `Support/Screens/` | Page objects (`PlayScreen`, `BattleScreen`, `TabBar`, …) |

Smoke membership is defined by the selected tests in `Smoke.xctestplan`,
mirrored in `Scripts/config/smoke-classes.txt`; `check-docs.py` fails when they
diverge, so update both together. The smoke command can filter the plan for
focused iteration.

## Launch args

Defined as `TestLaunchArg` in `Support/TrinketUITestCase.swift` and parsed by
`AppEnvironment`. Helpers include `allForScreen`, `allForTab`, `allForBattle`,
`allForBattleVictory`, `allForMidBattle`, `allForShop`, and
`completedStages`. Use the source type for the complete, current catalog.

**Default smoke args:** `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`.

Common screen-entry arguments are `-launch-screen` and `-selectedTab`; state
seeding uses `-completed-stages`, `-starting-gold`, and the reset/cloud-sync
flags. Performance-only frame metrics are opt-in and never belong to smoke.

Keep default launch args unless testing persistence. Prefer `AccessibilityID`
selectors and assert with `assertExists`; use visible text only when it is the
product contract. UI tests tap tab labels, not `AppTab` raw values.

## Speed

- Prefer `-launch-screen` / `-selectedTab` deep links; do not re-navigate a screen launch args already opened.
- Prefer one launch per class (`SeededSmokeUITestCase` or shared `setUp`) when methods share args; avoid `app.terminate()` + relaunch mid-suite unless args must change (then split classes).
- Prefer one launch + `TabBar` for round-trips that must exercise the tab bar itself.
- Prefer `-completed-stages` over scrolling Stage Select lists when seeding progress.
- Filter inventory/search with `replaceText` instead of grid scroll loops.
- Prefer `AccessibilityID` selectors over visible labels for primary CTAs (Aspect Begin Floor, Labyrinth node actions).
- Mid-battle exhaustive tests enter through the Play map with
  `TestLaunchArg.allForMidBattle()`; do not deep-link into a live battle when
  setup timing matters. Keep victory/performance ownership in the dedicated
  performance plan.
- Use the timeout and tick defaults from `TrinketUITestCase` and its helpers;
  do not copy their numeric values into this guide.
- Accessibility audits are intentionally not part of the test suite. Keep UI assertions focused on stable test selectors and interaction outcomes — not display names, rarity labels, or scroll geometry unless that string is the product contract.
- UI tests run serially on a single simulator by default. Hotspots: `python3 ./Scripts/test-timing.py report --top 30`.
