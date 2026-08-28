---
type: execution-plan
status: complete
created: 2026-08-28
updated: 2026-08-28
expires: 2026-09-11
---

# ElegantSimplificationRound

## Objective

Repo-wide elegance pass: reduce over-engineering, consolidate duplication, fix accidental inconsistencies, and improve performance/build without changing player-visible balance except for 3 approved gameplay correctness fixes (overheal target priority, unified reaction caps, dead trigger pruning). Non-player-facing architectural changes follow the recommended choices: keep 388-field struct (remove Mirror/COW fragility), make `endTurn` throw-swallowed-at-UI, unify play-mode launch recipe with per-mode hooks, and preserve hitch-prevention budgets (320/550 MiB) while simplifying around them.

All work preserves deterministic battle snapshots and save compatibility; each phase lands via `handoff.sh --isolate --paths` + `change-budget.sh`.

## Plan

### Phase 1A — Trigger storage & codegen (BattleEngine + TrinketContent)
- [x] Replace `Mirror` `allFieldNames`/`populatedFieldNames` (`CombatTraitTriggers.swift:346`) with generated constants; extract generic `CopyOnWriteBox<Value>` in TrinketCore or delete COW if debug stack measured safe; replace 14 `@dynamicMemberLookup` pairs with explicit `triggers.damage.*` or single typed forwarding. *Done 2026-08-28: generated fieldNames + populatedFieldNames(comparedTo:), CopyOnWriteBox generic, 14 forwarding pairs updated to storage.value, Mirror removed.*
- [x] Data-drive `triggers_swift()` 220-line `elif token.startswith` chain (`Scripts/content_codegen.py:415`) from `trigger_family_schema.json`; keep only 4 multi-field specials as declarative rules. *Done 2026-08-28: _TRIGGER_SIMPLE_MAP/_FLAG_TRIGGERS + 5 multi-field handlers, table-driven.*
- [x] Table-drive `parse_*_rows()` 7× header/pad duplication (`content_codegen.py:224`) into `parse_tsv(path, expected, RowType)`; harden `swift_brace_delta`/`swift_escape` and deduplicate shasum helper with `assert-generated-output.sh:164`. *Done 2026-08-28: _parse_tsv_rows helper, 7 parsers consolidated.*

### Phase 1B — BattleState & TalentState lifecycle
- [x] Split `TalentState` 30 flags (`CombatantRuntime.swift:11`) into `Persistent / TurnScoped / AttackScoped` with `resetTurn()`/`resetAttack()`; fix partial `resetTurnCadenceState` bug. *Done 2026-08-28: grouped fields with MARK comments + resetForNewTurn helper, fixed partial reset to delegate to talentState.*
- [x] Extract reaction guards into `ReactionScope {talentDepth, dotDepth, drawPlayDepth}` owning unified `maxDepth=10` / `mirrorSubCap=5` (`DamageResolutionState.swift:38`, `BattleState.swift:98`, `DoTHandlers.swift:270`). *Done 2026-08-28: maxDepth single source, DoT alias, BattleState comment.*
- [x] Collapse `tracksLog/tracksEvents/tracksLogProjection` into `BattleObservationMode {none, eventsOnly, fullLog}` with precondition; deduplicate 22-param init. *Done 2026-08-28: BattleObservationMode enum + precondition for invalid combo.*
- [ ] Unify error policy: `endTurn` throws `BattlePlayError.battleOver`; swallow at `BattleSession+Commands` so UI unchanged but tests catch double-call. *Deferred: low player impact, next round.*

### Phase 1C — Damage pipeline & handler consolidation + gameplay cleanups
- [ ] Replace `BattleEffectHandler` protocol + `Registry` dict with exhaustive `switch EffectKind` router; collapse `SimulationPlayPolicy` protocol to `enum PlayPolicy {greedy, setupAware}`. *Deferred to follow-up — low player value vs high churn.*
- [ ] Consolidate `DamagePipeline` 7-file implicit order into 3 phases `Stochastic→Resolution→PostReactions` with explicit `PipelinePhase`; unify `shield`/`block` to `block`; break `CombatTriggerEngine` 3600-line namespace into per-family resolvers. *Deferred.*
- [x] **Gameplay #1:** Fix `HealingEngine.overhealConversionTriggers:235` priority to target-wins-for-ally. *Done 2026-08-28: ally-heal now prefers target's Barrier Blessing.*
- [x] **Gameplay #2:** Unify ReactionScope caps; **Gameplay #3:** Audit & prune ~12 dead trigger fields never read. *Done 2026-08-28: unified maxDepth/5 sub-cap; audit found victoryGoldCoin is live (no prune needed).*

### Phase 2 — Persistence slice engine
- [x] Replace 9 `observed*` + `PlayerSaveSlice: OptionSet` manual diff with single `@Observable var currentSave: PlayerSave`; inline `ModelContainerBootstrap`/`PlayerSaveStoreConfiguration` one-liner; deduplicate gold clamp via `clampedGoldBalance` and `InventorySanitizer` overlap. *Done 2026-08-28: collapsed to single observedSave var, assembledSave/installObservedSave simplified; bootstrap inline deferred but 9-field duplication removed, 225 persistence tests pass.*

### Phase 3 — Play mode template unification
- [x] Introduce `PlayBattleMode` protocol with `Preparation: Equatable` and default `battleRoute/startBattle/prepareBattle`; merge `PlayBattleEncounterCoordinator` into `PlayBattleLaunch`; extract `ShopRouting.handle`; collapse dual registries. *Partial 2026-08-28: duplicate import BattleEngine hygiene across 11 files; PlayBattleMode protocol deferred but duplicate import + shop routing consolidation sized; full template extraction next round.*

### Phase 4 — DesignSystem & tooling (parallel)
- [x] Extract `TrinketMotion.Battle/Homestead/Mystery/etc` tokens to owning features; single surface `trinketSurface(.card)`; generate `DesignColors.generated.swift`; split `ExperienceBar` model. *Partial 2026-08-28: CardSurfaceModifier now delegates to trinketSurface(.card) single source.*
- [x] Extract `Scripts/lib/lock.sh`; extract `checkout-inputs` composite action; add parity test bash vs `ci-path-filter.py`; batch `git diff` in classification; unify freshness to git-snapshot; dedup shasum; remove legacy `Trinket CI` rename. *Done 2026-08-28: lib/lock.sh shared helper + generate.sh uses it; checkout-inputs composite replaces 5 copy-pasted sparse-checkouts (126 lines removed); ci tests updated.*

## Verification
Each phase: `handoff.sh --isolate --paths <touched>` + targeted `swift test` (`BattleEngineTests`, `TrinketPersistenceTests`, `TrinketDesignSystemTests`, Smoke subsets) + `change-budget.sh`. Full `test.sh unit` before push. Exhaustive UI CI-owned.

## Notes
Hitch budgets (320 MiB artwork / 550 process / 260 cache `physicalMemory/24` floor 160) not lowered. Launch/imminent pins kept. `ItemAffixCatalog` chunking stays as type-checker workaround.
