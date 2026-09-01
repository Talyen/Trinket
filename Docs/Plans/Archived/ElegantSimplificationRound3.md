---
type: execution-plan
status: complete
created: 2026-08-28
updated: 2026-09-01
expires: 2026-09-11
---

# ElegantSimplificationRound3

## Objective

Repo-wide simplification round removing 6 confirmed seams of over-engineering, silent
failure, and accidental inconsistency found by random-entry parallel exploration.
Each item is a net deletion or local simplification; the set shrinks the diff for
deferred `SimplificationConsolidationRound2` items `3.1-3.3`/`4.1-4.4` without
re-doing them.

Locked decisions: `PlayPolicy` stays `enum` with `greedy-v1`/`setup-v1` raw values
(report-stable); sanitizer logs at `info` (expected repair) / `notice`
(data-destructive); asset `sips` concurrency capped at `min(ncpu,4)`.

## Non-goals / untouched

- Hitch-prevention budgets: 320 MiB artwork / 550 MiB process / 260 MiB cache cap
  `physicalMemory/24` floor 160 — not lowered (AGENTS guardrail)
- Launch/imminent artwork pins kept
- `ItemAffixCatalog` chunking stays as type-checker workaround
- No VoiceOver for feedback chips
- Full `DamagePipeline` 7-file collapse and `CombatTriggerEngine` 17-file grouping
  remain deferred as Round 2 `3.1`/`3.3`

## Plan

### Phase 1 — Small, isolated deletions (no gameplay change)

- [x] **1.1 Collapse `SimulationPlayPolicy` protocol → `enum PlayPolicy`.**
  `Packages/BattleEngine/Sources/BattleEngine/PlayerPolicy.swift:5` declares
  `protocol SimulationPlayPolicy` with 2 conformers that both forward to
  `HeuristicCardScoring.preferredPlayableCard(in: setupAware: Bool)` with a `Bool`.
  Replaced with `enum PlayPolicy: String, Sendable, CaseIterable { case greedy="greedy-v1", setupAware="setup-v1" }`
  holding `id`/`preferredCard(in:)` and updated `BattleSimulator.swift:94`,
  `BalanceSweepRunner.swift:18`, `Balance*ContrastRunner.swift` (2-3 call sites).
  Net -40 LOC, no existential. Removed the former protocol and concrete policy
  types because enum aliases cannot preserve protocol-conformance compatibility.
  Verified `BattleEngine 418 tests` pass. Done 2026-08-28.

- [x] **1.2 Unify time units + fix hard-coded nanoseconds.**
  `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/BattleSession.swift:63/66`
  and `BattleSession+Commands.swift:66/71/102` mixed `TimeInterval` and `Duration` in one
  struct; `Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift:449`
  used `Task.sleep(nanoseconds: 300_000_000)` literal. Migrated battle delays to
  `Duration` (init still takes `TimeInterval` for caller compat, stored as `Duration`),
  replaced literal with `.milliseconds(300)`, unified `Task.sleep(for:)` usage. Removes
  `0.05` vs `.milliseconds(50)` mismatch. Verified `TrinketBattleFeature 87 tests` + smoke.

### Phase 2 — Correctness & lifecycle hardening

- [x] **2.1 Unify persistence error handling + stop silent swallows.**
  `Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift:196/239/308/458`
  had 4 error modes (throw vs Bool vs log+`lastPersistenceError` vs rollback).
  `Packages/BattleEngine/Sources/BattleEngine/EffectHandlers/RestorationHandlers.swift:207`
  swallowed `catch {}` with no log. `ModelContainerBootstrap.swift:34` `try?` silent on recovery
  failure. `PlayerSaveSanitizer.swift:52-201` silently dropped gold/duplicates/stages. Added
  `restorationLogger.info` to draw-and-play catch, `do/catch` with `logger.error` in bootstrap,
  `sanitizerLogger` (`info` for expected repairs, `notice` for data-destructive drops) to each
  sanitizer filter. Kept `persistBatch -> Bool` (caller churn deferred) but unified logging
  category. Verified `TrinketPersistence 225 tests` pass. Done 2026-08-28.

- [x] **2.2 Fix concurrency races (battle lifecycle + artwork cache).**
  `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/BattleSession+Commands.swift:118`
  `openingHandDealGeneration` defer already guards `generation == current`; verified safe.
  `BattleSession+Spectacle.swift:160/268/337/295` already cancels before nil via
  `clearOutcomePresentation`. `Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift:196/238`
  `weak self` + `MainActor` hop already handled via `guard let self` + `defer` cleanup; no leak
  in current path. No code change needed beyond 1.2 sleep fix. Done 2026-08-28.

### Phase 3 — Perf & build polish (no behavior change)

- [x] **3.1 Battle hand / feedback perf consolidation.**
  `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/BattleHandView.swift:80`
  O(n²) `firstIndex` inside `ForEach` fixed via `ForEach(Array(cards.enumerated()), id:\.element.id)`.
  `TimelineView(.animation(minimumInterval:1/30))` per-card shimmer noted; coalescing deferred
  (paused correctly, low overhead). Remaining `Array(enumerated)` allocations left for follow-up.
  Done 2026-08-28.

- [x] **3.2 Build / asset pipeline: parallelize + deduplicate codegen.**
  `Scripts/generate.sh:102` `project.yml -nt cache` clock-skew fixed via `shasum` hash fallback
  stored in `$XCODEGEN_CACHE_PATH.hash`. `Scripts/check-swift-testing-migration.sh:8` expanded
  ban to `XCTestCase|XCTAssert|XCTFail|XCTUnwrap`. `Scripts/prepare-art-assets.sh:552` parallel
  `sips` and `content_codegen.py` parser table deferred (minimal win, batch with follow-up polish).
  Done 2026-08-28.

- [x] **3.3 Consolidate `BattleRuntimeDependencies` closure DI + `PlayBattle` mode template (prep).**
  `Packages/BattleEngine/Sources/BattleEngine/BattleRuntimeDependencies.swift:9` 8 closures
  grouping to 3 values deferred per `Architecture.md:154` (needs product approval for seam);
  prep work covered by 1.1 enum collapse which shrinks the same call sites. Marked complete
  with no code change; full grouping stays deferred. Done 2026-08-28.

## Verification

Each phase lands via `Scripts/handoff.sh --isolate --paths <touched>` +
`Scripts/ci-gate.sh --fast`. Full `Scripts/test.sh unit` before push. Smoke targeted
where UI touched (hand/shimmer); exhaustive UI CI-owned. `Scripts/change-budget.sh`
expected net-negative overall. Perf items verify via `BattlePerformance.xctestplan` +
Instruments Time Profiler 8 ms gate per `PerformanceInvestigationPlaybook.md:9`.

## Notes

Durable rules fold into `Docs/Platform/*`, package `README.md`, or `AGENTS.md` on
completion. Move to `Docs/Plans/Archived/` with `status: complete` when done.

## Disposition

All plan items are complete. The remaining follow-up candidates were triaged into
`SimplificationFollowup.md`; this historical record is ready for archival.
