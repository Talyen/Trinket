---
type: execution-plan
status: active
created: 2026-09-02
updated: 2026-09-02
expires: 2026-09-16
---

# BattleEngineSimplification

## Objective

Make battles feel identical to players but make the combat engine simpler to own: fewer duplicated files, one clear place for each rule, and faster balance sweeps. Random draw chose BattleEngine (171 Swift files).

## Plan

- [x] Baseline: `swift build` + `swift test` green (38 tests), recorded duplication hotspots (damage 9 files, card engine 4 files, `BattleState+CombatResolution` delegation).
- [x] Phase 1A — shared emitters + DoT dispatch: add `BattleState+TriggerEmitters.swift` + `DefensePoolEngine+Policy.swift` (central holy/unbroken/burn checks) + table-driven talent mirrors (`DamagePipelineTalentReactions.swift:21-82` 6× → loop).
- [x] Phase 1B — damage policy centralization: `DefensePoolEngine+Policy.swift` + `applyDoT` helper replaces 3-way bleed/poison/burn branches; fix `resolveGuaranteedCrit` guard-order bug (`DamagePipelineStochasticSteps.swift:174-223`) and `phantomCounter` dot depth leak.
- [x] Phase 1C — card engine deduplication: `BattleCardCombatEngine.swift` `advanceRoundCommon` + `pickBalancedOwner` (dedup `endTurn:125-191` vs `endTurnWithoutDraw:7-77` and `drawCardsBalanced:287-329` vs `drawNextTurnStartCard:80-128`), explicit deck switch replaces `WritableKeyPath` (`deckKeyPath:331`), `BattleCardCombatEngine+OpeningHand.swift:11-15` fix retained RNG discard, `EffectSummaryBuilder.swift:19-33` single-pass grouping, delete `BattleState+CombatResolution.swift:5-86` merge into `BattleState.swift`.
- [x] Phase 1D — small wins: `leech share` `max(1,)` fix (`CombatTriggerEngine+Leech.swift:75`), parallelize `BalanceSweepRunner.swift:142-156` respecting `resolvedJobs` via `DispatchQueue.concurrentPerform`, same for `BalanceContrastSupport.swift:272`, add `Dispatch` imports.
- [ ] Phase 2A — single effect buffer + `preBlockDamage` + `DamageKind` + guard consolidation (deferred to follow-up; `buildupDamage` duality still present, 8-flag `ReactionScope` pending single `withScope`).
- [ ] Phase 2B — explicit `TalentState` + `TurnGuards` + `RestorationPipeline` (deferred; `@dynamicMemberLookup` still hide 30 talent flags, `HealingEngine+Leech` second path kept).
- [ ] Phase 2C — trim `EffectHandlers` registry to stateful handlers only (deferred).
- [x] Phase 3 — table-driven talent mirrors done; full `ReactionScope` flag remains deferred behind flag.
- [ ] Verification: `swift test --package-path Packages/BattleEngine` passes; `handoff --isolate --paths Packages/BattleEngine` pending final push gate.

## Notes

Deferred items remain valuable but exceed this slice's risk budget; they are recorded for next execution plan. `SimplificationFollowup.md` deferrals are now backed by line-level evidence and behind-flag plan; no player-visible balance changed (caps/constants identical, cap position unchanged). Durable rules to fold: `BattleCardCombatEngine` `advanceRoundCommon`/`pickBalancedOwner` semantics into `Docs/AgentContext/battle-engine.md` on completion.

## Verification (so far)

- `swift build --package-path Packages/BattleEngine` — green (2.9s).
- `swift test --package-path Packages/BattleEngine` — 38 tests pass, including `parallel identity matches sequential outcomes`.
- Remaining: full `handoff.sh --isolate --paths Packages/BattleEngine` + `check-docs.py` before push.
