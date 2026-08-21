# TrinketUITests

UI test mechanics for Trinket. Agent workflow: `AGENTS.md`. Semantic test
ownership and keep/drop rules: [`Docs/Platform/Testing.md`](../Docs/Platform/Testing.md).
UI selector constants live in `Packages/TrinketFeatureSupport`.

## Layout

| Area | Path | When |
|------|------|------|
| Smoke | `Smoke/`, `Smoke.xctestplan` | Local and CI `test.sh smoke` (registry-defined classes) |
| Exhaustive | `Play/`, `Collection/`, `Battle/` | Main CI (sharded); local only for targeted debugging |
| Performance | `Performance/`, `BattlePerformance.xctestplan` | Ad hoc `performance.sh` / `test.sh performance` when investigating performance; not CI or smoke |
| Support | `Support/Screens/` | Page objects (`PlayScreen`, `BattleScreen`, `TabBar`, …) |

Smoke membership is defined by `Smoke.xctestplan` and
`Scripts/config/smoke-classes.txt`; the test plan is the source of truth when
classes change. The smoke command can filter the plan for focused iteration.

## Keep / drop

Prefer extending an existing kept method over a new class. Push rules and
persistence to package tests; UI proves the shipping control path once.

## Launch args

Defined as `TestLaunchArg` in `Support/TrinketUITestCase.swift` and parsed by
`AppEnvironment`. Helpers include `allForScreen`, `allForTab`, `allForBattle`,
`allForBattleVictory`, `allForMidBattle`, `allForShop`, `allForMystery`, and
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
- UI tests run serially on a single simulator by default. Hotspots: `./Scripts/test-timing.sh report --top 30`.
