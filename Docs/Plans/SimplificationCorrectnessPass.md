---
type: execution-plan
status: active
created: 2026-08-21
updated: 2026-08-22
expires: 2026-09-04
---

# SimplificationCorrectnessPass

## Objective

A repo-wide simplification and correctness pass: delete never-configured plumbing, collapse copy-paste duplication in views and engine paths, fix verified combat-accounting and save-mapping bugs, close silent-exclusion gaps in tooling. Every finding below was verified against source (file + line cited). Items marked **[GAMEPLAY]** change what players see or how fights resolve — approval needed on those specifically; everything else is behavior-preserving cleanup, test coverage, or tooling repair.

Work is organized as five independently landable phases, highest value first.

---

## Phase 1 — Combat correctness (BattleEngine)

1.1 **`detonateBleed` silently deletes overcap Bleed stacks.** `CombatTriggerEngine+Damage.swift:463-504` collects *all* active Bleeds on the target, removes *all* of them (`removeAll { .bleed }`, :482-488), then resolves at most 3 ticks total. Excess Bleed vanishes without dealing damage. **Approved semantic (Option B): consume all — drop the tick cap so every removed stack actually detonates.**

1.2 **Intercede's blocked damage doesn't feed leech math.** The block redirect bypasses the `blockedAmount` input that lifesteal-style triggers read, so blocking for an ally yields no leech for the interceptor. One-line plumbing fix plus a deterministic test. **Approved.**

1.3 **Four heal sites bypass `HealingEngine.resolveHeal`** and skip heal-blocking / heal-multiplier / overheal rules: `DeathsDoorEngine.swift:133-137` (revive), `:283-287` (Afterglow), `:315-319` (Endless Legion top-up), `HealingEngine.swift:204-207` (overheal→max conversion). Route through `resolveHeal` with an explicit revive/raw flag as needed. **Approved** — audit live content for actual number impact and report.

1.4 **Control-meter threshold basis flips mid-battle.** `ControlMeterEngine.swift` stores the *base* threshold on partial buildup (:78-89) but the *reduced* threshold once reached (:163-174). Freeze decay then compares against whichever got stored. No live failure today (nothing reduces freeze thresholds yet) — fix by storing base canonically and applying reductions only when comparing.

1.5 **One RNG idiom.** Four sites roll via `Bool.random(using:)` directly (`CombatTriggerEngine+Defense.swift:178`, `+Mana.swift:279`, `+Resources.swift:78`, `EnemyTraitEngine.swift:37`) while `BattleChance.succeeds(probability:using:)` owns probability elsewhere. Standardize on `BattleChance`.

## Phase 2 — BattleEngine simplification

2.1 **Collapse five copies of the once-per-action guard** inside `afterSpendMana` handling plus a copy-pasted Golden Touch block and two dead locals (per exploration of EffectHandlers/). Local edits, no API churn.

2.2 **Resolve-time status snapshot.** Affliction checks use raw `.keyword ==` scans while control-status checks go through `hasControlStatus`; party aura merges (`BattleState.partyTriggers`, re-merged per access from `CombatTriggerEngine+Damage.swift:120/124`) and `CombatantRuntime.primaryStats` (rebuilt per access) repeat O(effects) work dozens of times per resolution. Compute a small snapshot (status flags + bonus aggregates) into `DamageResolutionState` once per resolution. Deduplicates logic *and* speeds up balance sweeps (thousands of battles × up to 500 actions).

2.3 **`BattleState` dual initializers list ~40 fields twice and already dropped one**: neither init threads `drawAndPlayDepth` (declared `BattleState.swift:99-102`), so restore through init #1 would reset nested auto-play depth. Collapse to one init with defaults (or a `Snapshot` struct).

2.4 **Test factory consolidation.** `makePipelineContext` and `makeContext` hand-build states with different defaults (`nextEventID` 0 vs 1); `standardParty` and `EffectHandlersTestSupport.makeBattle` wrap the same factory differently; the literal companion fixture appears 29× despite an existing `passiveCompanion()` helper. Consolidate onto `BattleStateTestFactory.makeBattle` with knobs; default companion argument.

2.5 **Split `CombatTriggerTalentTests.swift` (1,666 lines)** along its existing groups (damage-trigger / defense / resource suites), retiring both swiftlint suppressions without moving coverage.

## Phase 3 — Presentation simplification (TrinketBattleFeature / app)

3.1 **Delete `BattleHandMotionConfiguration`.** A ~198-line, 40-field motion config whose every production call site passes `.init()` (`BattleView.swift:372`, `BattleFieldLane+CardPlay.swift:10`) and whose hand-written `==` exists because auto-synthesis took >400 ms. Promote values to constants on `BattleHandLayout`/`TrinketMotion`, delete the struct, its Equatable helpers, the threading through three view layers, and the dead "Production entry point" forwarding init (`BattleHandView.swift:130-159`). Roughly 250 lines removed.

3.2 **One shared placeholder-artwork view.** The same ZStack (tint wash + symbol icon) is copy-pasted across 9 files with 3 diverged sizing strategies — two hard-pin point sizes and one hard-codes `size: 64`, so those copies don't scale with Dynamic Type (**user-visible inconsistency for large-text users**; fixing it is the point of consolidation). Extract `PlaceholderArtwork` in TrinketDesignSystem; delete all nine copies.

3.3 **Outcome-screen tidy.** Delete dead `VictoryView.enemyName`; replace string-derived accessibility IDs (`primaryActionTitle == "Loot All" ? … : "\(title) Button"` — renaming copy silently breaks UI tests) with explicit stable IDs; fold `BattleOutcomeShell` (now one consumer, unused optional params) into DefeatView.

3.4 **Map artwork dedup.** `SpireFloorArtwork` (`SpireClimbView.swift:163-188`), `EncounterArtwork` (`PlayMap/EncounterArtwork.swift:24-61`), and `LabyrinthNodeArtwork` (`LabyrinthMapClusterViews.swift:352-399`) re-implement the same prepared-image→fallback chain. Extract one `MapEncounterArtwork` next to `MysteryEventHeroArtwork`.

3.5 **Small items:** rename `CollectionGridShell`'s `EmptyView` generic param (shadows SwiftUI's type); rename misnamed `CombatFeedbackEventView.swift` (contains no view) to `CombatFeedbackMotionSampler.swift`; have `tickMotion` reuse `compositorPose` instead of duplicating chip-motion math (`CombatFeedbackRasterHost.swift:174-252`); fix `CombatantDetailPane` building the combat build twice on first render (body nil-coalesce + `onAppear` both call `makeCombatBuild()`).

## Phase 4 — Persistence & content integrity

4.1 **Inventory mapping exists twice.** `InventoryItemModel.init(item:)` (`InventorySaveModels.swift:33-46`) and `update(from:context:)` (`PlayerSaveModelMapping.swift:57-82`) copy identical field sets through separate code; adding a property to `InventoryItem` requires editing both or inserts persist differently than updates (silent data-loss shape). Make init delegate to update.

4.2 **Drop double sanitization.** Journey/spires setters pre-sanitize (`PlayerSaveStore.swift:67,87`) even though `mutate` → `sanitize(changedSlices:)` re-sanitizes every changed slice anyway; sibling setters don't. Remove the pre-sanitize calls, making one convention.

4.3 **Missing round-trip proof.** No store-level reopen-and-assert test covers the Spires slices or ability loadouts (the exact places with clamping at write time and silent tier-default fallback at read time). Add one test each in the existing style, per the package-local rule that new store APIs prove reload survival.

4.4 **Persisted role literals are lowercase while the domain enum rawValues are capitalized** (`"hero"/"companion"` at `PlayerSaveModelMapping.swift:98-106,219-220` vs `case hero = "Hero"`) — a trap where "fixing" to `.rawValue` breaks decoding of shipped saves. Simplest fix without schema migration: derive membership from `RosterHydration.combatantsByID[…]?.role` and drop the ad hoc strings; alternatively document the convention loudly. Decide during implementation after checking SwiftData schema implications.

4.5 **Delete `initial` aliases of `testSeed`** on `PlayerState`/`PlayerRosterState` (`PlayerState.swift:16-22,120,156-158`): production-sounding names handing out fully-unlocked fixtures; sole consumer is a test-support default argument.

4.6 **Consolidate legacy-ID remap tables** (talent renames procedurally in `PlayerSaveSanitizer.swift:266-275`; ability renames via switch in `RosterHydration.swift:109-118`) into one `LegacyIDRemap` owned by TrinketContent next to the catalogs they track, with an invariant test asserting every remap target exists in the current catalog (future catalog renames then fail loudly in CI instead of silently degrading saves).

4.7 **Dictionary indexes where linear scans compound:** `homesteadNode(matching:)` is `first {}` inside the production loop over all nodes (`HomesteadCore.swift:162-167` → O(n²) per collect/grant); mystery-event lookup same shape; roster mapping does `heroes.contains` per row instead of using the existing `combatantsByID` index.

4.8 **Split `ItemCatalogTypes.swift` (516 lines, four unrelated concerns)** along existing seams: affix roll/scale machinery + reflected key-path table → `ItemAffixPower+Roll.swift`; magnitude roll type out; leave value types together.

4.9 **World-seed resolution isn't idempotent** (`PlayerSaveSanitizer.swift:17,46-55` invents a random seed when absent, contradicting the sanitizer's own documented contract). Masked today because both entry points persist immediately; make assignment explicit ("pin once at root creation") or lazily pin in `PlayerSave`.

## Phase 5 — Tooling repairs

5.1 **Timing history keeps exactly one entry**, making multi-run hotspot reporting, `--by-class` aggregation, and CI step-summary trends dead code (`Scripts/test-timing.py:142`, undocumented `TRINKET_KEEP_TIMING_HISTORY`). Default history to ~50 entries.

5.2 **Delete `test-timing.sh ingest <mode>`** — it looks for `<mode>.xcresult` which no producer ever creates (writer uses `<label>-<token>.xcresult`), so the subcommand always fails, and the empty-log hint recommends running it. Remove subcommand, fix hint.

5.3 **`ci-diagnostics.sh --keep` only parses in position 2**; e.g. `--cleanup <path> --keep` silently proceeds to delete retained failure evidence. Parse args in a loop like every other script.

5.4 **Single smoke-class registry.** `Scripts/lib/smoke-classes.sh` and `Scripts/config/smoke-classes.txt` hand-list the same four classes with no cross-check; drift fails handoff late with an opaque xcodebuild error. Derive shell constants from the txt file (or assert equality in `test-scripts.sh`).

5.5 **Close the FullUI/CI silent-exclusion gap.** New UI test classes outside Smoke/Performance run nowhere if not hand-added to `FullUI.xctestplan` and the `tests.yml` shard matrix — no check notices (Smoke has this guard; FullUI doesn't). Extend `check-docs.py` structural checks: every `…: TrinketUITestCase` class outside Smoke/Performance must appear in FullUI, and every FullUI class must appear in the tests.yml matrix.

5.6 **Small fixes:** un-expand bug in `agent-context.sh --help` (quoted heredoc prints literal `${MAX_WORKING_TREE_PATHS}`); drop dead `TrinketUITests/Homestead/*` pattern in `change-classification.sh:208`; record timing on the packages-only failure path in `test.sh` (mirrors app path); add `build-for-testing.sh` / `test-timing.sh` / `agent-watch-ci.sh` rows to the Scripts README command index.

---

## Sequencing & verification

Each phase lands independently via path-scoped verification (`./Scripts/handoff.sh --isolate --paths …`):
- Phases 1–2: BattleEngine package tests (deterministic combat tests required for 1.1–1.4 per package-local rule).
- Phase 3: TrinketBattleFeature + DesignSystem + app-target tests; UI smoke plan for 3.3.
- Phase 4: TrinketPersistence + TrinketContent tests.
- Phase 5: Scripts self-tests (`test-scripts.sh`) + docs checks.

Change-budget warnings expected on deletions (net-negative lines); justifications noted inline above.

## Explicitly checked and clean (do not re-litigate)

No force-unwraps/retain-cycle issues anywhere surveyed; handler registry (~30 real conformances) earns its keep; recursion guards sound; deferred-save rollback chain tested; diagnostics Python family is layered, not duplicated; no dead scripts; catalogs already dictionary-indexed except 4.7's three cases; AppState layering clean.

## Resolved decisions

- **1.1**: Option B approved — detonation consumes all Bleed and resolves every tick (cap removed). Done; deterministic test added.
- **1.2 / 1.3**: Both approved as behavior corrections.
- **1.2 outcome correction**: `blockedAmount`'s only reader is the *attacker's* leech (`HealingEngine+Leech`), so Intercede absorption never fed the interceptor's lifesteal — that framing was wrong. Kept the one-line accounting fix (`state.blockedAmount += heroAbsorbed`) because blockedAmount should mean "total absorbed this resolution"; no live content combination makes it observable today.
- **1.3 outcome**: Afterglow and Endless Legion now route through `HealingEngine.resolveHeal` (floor semantics preserved for Legion, tests pin both). The trait death-revive stays a documented direct mutation: routing it Wisdom-scaled the flat "restore 10 Health" contract (caught by `TalentCatalogRoundTripTests`) and would let debuff gates suppress death protection. The freeze/heal-block gate is enemy-only (`CombatTriggerEngine.swift:74-78`), so it never applies to hero-side intrinsic heals.

## Status

All five phases implemented. Verification state:

- **Green, isolated per-package runs**: BattleEngine (~405 tests incl. new detonation + Endless Legion coverage and the split talent suites), TrinketContent (incl. `LegacyIDRemapInvariantTests`), TrinketPersistence (incl. new Spires/loadout reload proofs), TrinketDesignSystem, TrinketFeatureSupport (+adapters), TrinketBattleFeature, TrinketAppState, TrinketCore.
- **Style gate** passes on every file touched by this plan; `test-scripts.sh` green after Phase 5.
- **Pending**: the full-repo unit sweep was blocked by a concurrent session's in-flight Labyrinth modifier work (`LabyrinthModifierExpansion.md`): `BattleLoot.resolve` was mid-signature-change. The two compile completions made on that session's behalf went beyond grouping — `LabyrinthModels.primaryActionTitle` ("Approach"), and `LabyrinthCompletion.nonCombatGoldStipend`, which dropped its `effects:` parameter and altar cost as part of that plan's Part A forge removal. Both plans' work now shares this tree; see LabyrinthModifierExpansion's Status section. Re-run `./Scripts/test.sh unit` before push.
- **Approved out-of-scope rider (2026-08-22)**: the PD-007 accessibility-policy rewrite (`Docs/Product/Decisions.md`) with its repo-wide Reduce Motion removal, accessibility-size layout collapse, and `.large`-pinned feedback chips — plus the starter roulette onboarding redesign — rode in this tree unscoped by any plan. Both were reviewed and explicitly approved to land as-is; the policy is now threaded through the feature context card and apple-design skill.

Deliberately left untouched: `LabyrinthMapClusterViews.swift` artwork (distinct hex-map visual language, not the near-clone it appeared to be), `EffectHandlersTestSupport.makeBattle` wrapper (distinct defaults, widely aliased), foreign working-tree edits outside this plan's scope.
