# Codebase improvement plan — bugs, performance, simplification, tests

Date: 2026-08-11
Status: Active execution plan (delete when finished)
Scope: Whole-repo exploration for confirmed improvement candidates across four categories. Every item was verified by reading the relevant code before inclusion; candidates that could not be confirmed are omitted.

Guiding rules applied: smallest change that removes the confirmed cause; prefer delete → reuse → simplify → parameterize; keep behavior-deterministic changes in `BattleEngine` with tests that fail on the old behavior; path-scoped verification before any commit.

---

## Phase 1 — Correctness fixes (do first)

### 1.1 Frostwarden Freeze trait never builds a freeze meter (P1, wrong behavior)

- **Evidence:** `Packages/BattleEngine/Sources/BattleEngine/EnemyTraitEngine.swift:81-86` sends the per-turn Freeze damage with `DamageOptions(…, isRetaliation: true)`. `DamagePipelinePostSteps.applyControlMeter` (`Packages/BattleEngine/Sources/BattleEngine/DamagePipelinePostSteps.swift:87`) skips the meter charge whenever `state.isRetaliation`. The trait is authored as "Deals 1 Freeze damage per turn to all enemies" (`GameContentTraits.generated.swift`), so the freeze mechanic (meter buildup → action skip) is entirely dead; the trait currently just deals 1 flat damage.
- **Fix:** stop tagging this damage as retaliation. Note the blast radius: `DamagePipeline.swift:42-47` gates `applyControlMeter`, `applyReactiveOnHit`, `applyKeywordReactions`, and `applyCriticalReaction` together on `!isRetaliation`, so removing the flag re-enables all four, not just the meter. Because party on-hit/ward ping-pong is otherwise possible, add a targeted, named option (e.g. `applyControlMeter: Bool` alongside `isRetaliation`) that re-enables meter charge while still suppressing the reaction/recursion paths — do not rely on removing the flag alone. `EnemyTraitEngine.traitThornsDamage` (`:187`) legitimately keeps `isRetaliation`; leave it untouched.
- **Why this size:** the damage is an ordinary enemy turn action, not retaliation; the freeze meter rebuild is the authored behavior. A named option keeps the recursion guard intact.
- **LOC direction:** ~0 production LOC change + 1 new test.
- **Test:** add a deterministic test in `BattleEngineTests` (existing trait-flow pattern, e.g. `EnemyTraitBattleTests`): an enemy with the Frostwarden trait ticks effects; assert the party member's freeze meter charges and, at threshold, an action skip is pending.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 1.2 Mystery choice silently applies the *first* choice for a stale/mismatched choice ID (P2, silent wrong behavior)

- **Evidence:** `Packages/TrinketAppState/Sources/TrinketAppState/State/MysteryEncounterSession.swift:200`: `let choice = event.choices.first { $0.id == choiceID } ?? event.choices.first`. A non-matching non-nil `choiceID` falls through to the first choice, then grants that choice's effects and completes the node. The only legitimate `nil` path is single-choice auto-resolve (`EncounterPlayMode+Mystery.swift:54`, recruit events).
- **Fix:** branch on `choiceID`: if nil, use `event.choices.first` (existing single-choice behavior); if non-nil, require a real match and return `.failed` via `markResolvedWithoutReveal()` otherwise.
- **Why this size:** the fallback serves exactly one caller (nil); a stale tap should fail, not silently pick a reward.
- **LOC direction:** ~+3/-2.
- **Test:** `TrinketAppStateTests` mystery suite — stale `choiceID` yields `.failed` and does not complete progress; existing nil/single-choice tests must still pass.
- **Verify:** `./Scripts/test-package.sh TrinketAppState`.

### 1.3 `.defeatedAlly` resolves to the living companion when no ally is down (P2, wasted revive action)

- **Evidence:** `Packages/BattleEngine/Sources/BattleEngine/BattleTurnEngine.swift:432-440` returns `context.companion` when neither hero nor companion is defeated; `ReviveHandler` rejects any target with `health > 0` (`EffectHandlers/AbilityMechanicHandlers.swift:303`), so a revive cast with everyone alive targets the companion, is rejected, and the action is consumed.
- **Fix (recommended):** in the "nobody defeated" case, do not silently target the companion. Keep the function total by returning the hero (primary) — but reject the cast before the action is consumed. **Precheck location matters:** `playCard` removes the card from hand at `BattleCardCombatEngine.swift:67` *before* effect handlers run, so a targeting precheck inside effect application is too late to stop the card burning. The precheck must gate card play at `playCard` entry (before `hand.remove`), or be the UI-gating alternative below. Existing revive behavior with a downed ally is unchanged.
- **Why this size:** one default branch + one precheck at `playCard`; the alternative adds UI wiring across a package boundary.
- **LOC direction:** ~+5/-1 + 1 test.
- **Test:** `BattleEngineTests` — cast `.revive` with everyone alive; assert the action is not consumed and no revive occurs; existing revive tests (with a downed ally) must still pass.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.
- **Note:** the UI-gating alternative is a propose-and-stop candidate if product prefers player-facing gating; engine fix ships first.

---

## Phase 2 — Performance (battle feedback / effects)

### 2.1 Rebuild Slice particle arrays on every animation frame (P1, frame hit on enemy defeat)

- **Evidence:** `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Effects/CombatantSliceEffect.swift:72-81` calls `SliceBorderParticle.make(count: 24, …)` twice and `SliceCutParticle.make(count: 48)` once inside `slice(size:)`, which `body` invokes every `TimelineView(.animation)` tick for the 1.25 s enemy-death clip. Each `make` calls `CombatantCardEffectNoise.value` (trig-based) per particle (~1000 trig/noise ops + ~96 struct allocations per frame). The particles depend only on fixed config (count/isPrimary/salt), never on `progress`. `CardCastOverlay.swift:335-336` already caches the equivalent particles as `static let`.
- **Fix:** hoist the three arrays to cached `static let`s (deterministic by construction), matching the existing `CardActivationParticle` pattern. **Assumption to record in code:** there is exactly one production instantiation site (`BattleSliceArtwork` default `.production` config), so the cache bakes in production values; a future non-default config must be handled explicitly, not silently ignored.
- **Why this size:** pure memoization of deterministic work; no behavior change.
- **LOC direction:** ~-10/+8.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature` + `./Scripts/test.sh unit` (Battle smoke/perf path unchanged).

### 2.2 `BattleFeedbackLane.pruneExpired` nested linear scan (P2, dense-turn prune cost)

- **Evidence:** `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/BattleFeedbackLane.swift:147-151` iterates every recorded event (up to ~0.68 s of events, tens on dense turns) and runs `activeItems.contains { $0.sourceEventIDs.contains(eventID) }` per entry — O(M·N). `pruneExpired` runs on every card play, end turn, and prune-timer fire.
- **Fix:** build `let referencedIDs = Set(activeItems.flatMap(\.sourceEventIDs))` once, then test `!referencedIDs.contains(eventID)`.
- **Why this size:** a one-line set materialization replaces the nested scan; no structure changes.
- **LOC direction:** ~+1/-1.
- **Verify:** BattleFeature package tests (feedback-lane tests assert prune/expiry behavior).

### 2.3 `CombatFeedbackRasterPool.markMostRecent` does O(capacity) array work per cache hit (P3)

- **Evidence:** `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Feedback/CombatFeedbackRasterPool.swift:325-330` runs `recency.firstIndex(of:)` + `remove(at:)` (both O(C), C=384) + append on every raster hit in `cachedRaster`/`prepare`.
- **Fix:** short-circuit when `recency.last == key` (already most recent — the common repeated-key case), avoiding the remove/re-append churn. Optional follow-up if profiling warrants it: index-map the recency array.
- **Why this size:** removes the dominant cost of the common case with a guard; the index-map is a larger structure change reserved for measured need.
- **LOC direction:** ~+2.
- **Verify:** existing `CombatFeedbackRasterPool` LRU/eviction tests must still pass unchanged.

---

## Phase 3 — Remove dead / over-engineered surface

### 3.1 Delete `CombatFeedbackFloatRecipe.idealCore` dual path (P1, shipped parallel implementation)

- **Evidence:** `Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/TrinketMotion.swift:8,141,215-296` — full parallel envelope (duration constant + 3 sampling functions + switch cases) with **zero production callers**; only `TrinketMotionTests.swift:55` references it. The doc comment admits it "remains implemented for comparison and revert."
- **Fix:** delete the case, its switch arms, the `idealCore*` sampling functions, `activeFloatRecipe`, and the `idealCoreChipMotionUsesEaseOutRiseAndFade` test. **Keep `chipTravelFraction` and `chipTopClearance`** — they feed `chipTravelDistance`, which is production-used (`CombatFeedbackRasterHost.swift:182,235`). Only the six idealCore-only constants are dead (`chipStartScale`, `chipPeakScale`, `chipEndScale`, `chipPeakProgress`, `chipOpaqueHoldFraction`, `chipFadeOutDuration`). Because the helpers become single-valued, drop the `recipe` parameter from `chipMotionProgress`/`chipScale`/`chipOpacity`/`displayDuration`, update the call sites (`CombatFeedbackEventView.swift:38-41`, BattleFeature lifetime reads) and the `recipe:` arguments in `alchemyPopChipMotionUsesPopHoldCubicRiseAndFade`.
- **Why this size:** repo discipline: "Refactors remove the replaced path"; dual shipped recipes for "revert" are exactly the retained path the change rules forbid.
- **LOC direction:** ~-55 production, -20 test.
- **Verify:** `./Scripts/test-package.sh TrinketDesignSystem` (then grep `idealCore` must be empty).

### 3.2 Delete `AppEnvironment.battleTickInterval` dead config (P1, dead launch config)

- **Evidence:** `Packages/TrinketAppState/Sources/TrinketAppState/App/AppEnvironment.swift:19,152-159` — field + parser claim to "override the default 1s battle tick interval in BattleView", but no production code reads it (`rg battleTickInterval` matches only `AppEnvironment` + `AppEnvironmentTests.swift:72,78,96`).
- **Fix:** delete the field, parser, `-battle-tick-interval` handling, and its three test cases.
- **Why this size:** unused configuration is dead surface; the doc-comment claim is stale.
- **LOC direction:** ~-25 total.
- **Verify:** `./Scripts/test-package.sh TrinketAppState` + grep for `battleTickInterval` empty in production.

### 3.3 Collapse `EnemyPowerMultipliers` split (P2, parameterization never exercised)

- **Evidence:** `Packages/TrinketCore/Sources/TrinketCore/EnemyPowerCurve.swift:3-10` — `EnemyPowerMultipliers.health` and `.stats` are always equal (`multipliers()` builds `EnemyPowerMultipliers(health: stats, stats: stats)`); `.uniform` has zero callers. `GrowthArchetype.swift:110-123` 4-arg `applyPowerMultiplier` overload is called only by `StatGrowthTests`; production (`BattleEngine/Sources/BattleEngine/CombatantLevelScaler.swift:23-28`) uses the 5-arg form with equal multipliers.
- **Fix:** replace `EnemyPowerMultipliers` with a single `Double` power multiplier; drop `.uniform` and the 4-arg overload; migrate `StatGrowthTests` to the surviving call.
- **Why this size:** two fields are never distinct — a single value is the confirmed simpler model; no behavior change.
- **LOC direction:** ~-30 total.
- **Verify:** `./Scripts/test-package.sh TrinketCore` and `./Scripts/test-package.sh BattleEngine`.

### 3.4 Remove confirmed small dead surface (P3 bundle — each gated on an `rg` re-confirmation at execution time)

- `ItemAffix.placeholder` — `Packages/TrinketContent/Sources/TrinketContent/ItemCatalogTypes.swift:40-46`; no callers. Delete.
- `BattleSimulator.swift:92` — `(timedOut ? .defeat : .defeat)` both arms identical; collapse to `?? .defeat`.
- Design system unused roles — `Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/VisualFoundation.swift`:
  - `MaterialRole.toolbar/.modal/.popover` — no callers (production uses `.bottomBar/.subtleOverlay/.homesteadFooter`; `.rewardReveal` is preview-only).
  - `TypographyRole.tooltip` — no callers.
  - `SurfaceRole` cases beyond `.secondary`/`.denseRow` — production-unused; confirm each case via `rg` before removal (previews may reference them).
  - `HomesteadPalette` wrapper (`VisualFoundation.swift:81-91`) — production uses only `.accent`/`.success` (`VerticalPathRail.swift`); `.background`/`.panel` are asserted only by `PaletteTests`. Inline the two colors into `VerticalPathRail`, delete the enum, and update `PaletteTests`.
- `ArtworkBlend` unused destinations — `ArtworkBlend.swift:4-26`; production constructs only `.bottom(into: .canvas)`; drop `.perimeter` and unused destinations.

---

## Phase 4 — Test optimization / de-duplication

### 4.1 Trim `BattlePresentationControlSkipTests` to non-duplicative cases (P2)

- **Evidence:** `Packages/TrinketBattleFeature/Tests/TrinketBattleFeatureTests/BattlePresentationControlSkipTests.swift` (161 lines) re-tests border-accent and buff-aura scenarios already owned by `BattleEngineTests/CombatantBorderAccentTests.swift` and `CombatantBuffAuraTests.swift`, through a thin delegation (`BattlePresentationSnapshot` → `CombatantBorderAccent.keyword` / `CombatantBuffAura.kind`, `BattlePresentationState.swift:58,62`). Same fixtures, same expectations.
- **Fix:** delete the pure-delegation tests (shadowstep aura, avatar aura, Death's-Door-outranks-border, party-border-while-awaiting). Keep the `ownerControlSkipKeywords` projection cases (computed in BattleFeature at `BattlePresentationState.swift:66`) and the one cross-cutting lingering case (`ignoresPartyControlStatusLingerForHandAndBorder`).
- **Why this size:** keeps the BattleFeature-unique projection coverage; engine tests remain the semantic owner of the mapping.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature`.

### 4.2 Dedup Labyrinth adjacency test (P2)

- **Evidence:** `Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:399-455` (`clearedHexMakesAllSixNeighborDirectionsReachable`) duplicates the six-neighbor adjacency matrix already asserted by `TrinketContent`'s `LabyrinthCatalogTests.gridPositionAdjacencyMatchesSixHexNeighbors`, through Persistence's `isNodeReachable`/`reachableNodeIDs`. **Corrected scope:** the `hasClearedAdjacentPath` helper (`:374-396`) is NOT a duplicate — production reachability (`LabyrinthProgress.swift:54-97`) is single-hop adjacency to a cleared hex and excludes cleared nodes, so it cannot express the transitive cleared path entry→boss the sanitize test (`:102`) needs. Keep the helper and its sanitize usage.
- **Fix:** trim `clearedHexMakesAllSixNeighborDirectionsReachable` to the Persistence-unique semantics: keep a compact assertion that a cleared center makes its six neighbors reachable (distance-one only, cross-cluster/distant nodes excluded) so `isNodeReachable`/`reachableNodeIDs` stay covered without re-asserting the Content adjacency matrix.
- **Why this size:** removes cross-package duplication of a proven invariant while keeping Persistence's reachability semantics covered.
- **LOC direction:** ~-30 test.
- **Verify:** `./Scripts/test-package.sh TrinketPersistence` and `./Scripts/test-package.sh TrinketContent`.

### 4.3 Remove AppState tautologies / shallow duplicates (P2)

- **Evidence:**
  - `AppStatePlayFlowTests.swift:347-377` (`completeActiveBattleGoldMatchesVictorySummaryWhenHomesteadBonusActive`) recomputes `expectedTotal` from the very production functions under test (`BattleLoot.resolveJourney`, `StageCompletion.resolvedGoldReward`) — vacuous math; the gold split is already owned by `BattleVictorySummaryTests.makeVictorySummaryKeepsRawBattleGoldSeparateFromHomesteadDisplaySplit`. **Prefer pinning `expectedTotal` as a concrete constant** (e.g. `initialGold + 30` style with a comment) over deletion: the test still covers the raw-gold passthrough wiring in `completeActiveBattle` (battleEarnedGold → summary, not the homestead display split), which is a real behavior not owned elsewhere.
  - `AppStatePlayFlowTests.swift:280-289` (`unlockAllContentUnlocksRosterAndClearsBattle`) is a shallow duplicate of `PlayerSaveStoreTests.unlockAllContentUnlocksRosterAndClearsChapterOne`; its name claims a roster assertion it never makes.
- **Fix:** delete the gold-math test (or pin its expected total as a constant); trim `unlockAllContent` test to the AppState-unique assertions (`activeBattle == nil`, tab preserved) or delete if `clearTransientState` coverage owns that.
- **Verify:** `./Scripts/test-package.sh TrinketAppState`.

### 4.4 Hoist the duplicated deterministic seed (P3)

- **Evidence:** the literal `1772` is inlined in ~10 BattleEngine test files plus `HealingEngineTests.swift`, `BattleTurnEngineTests.swift`, `DamagePipelineTests.swift`, `HeroCompanionTraitTestSupport.swift`, etc.; two private constants duplicate it (`BattleStateTestFactory.swift:14`, `BattleTestFixtures.swift:13`); BattleFeature re-declares it as `deterministicBattleSeed` (`BattleSessionTestSupport.swift:14`).
- **Fix:** one shared named constant in the BattleEngine TestSupport layer referenced by all BattleEngine test files; if the package graph allows, also share into `TrinketTestSupport` for the BattleFeature copy (check `TrinketTestSupport`'s dependency direction first — do not introduce a cycle).
- **Why this size:** a single constant replaces ~15 spelling sites; seeds are behavior-pinning, so one canonical name prevents drift.
- **Verify:** full unit suite (`./Scripts/test.sh unit`).

### 4.5 Pin Mystery XP assertions instead of re-deriving the formula (P3)

- **Evidence:** `MysteryEffectApplierTests.swift:26-39,92-105` computes `expectedHeroXP` via `ExperienceScaling.cappedAward(ExperienceScaling.equalBattleAward(...))` — the exact formula under test — so both sides move together and a scaling regression passes.
- **Fix:** assert concrete pinned XP values for the seeded level-1/level-20 cases; keep the wiring assertions (gold, material grant, roster mutation).
- **Verify:** `./Scripts/test-package.sh TrinketPersistence`.

### 4.6 Remove the tautological glyph reference baker and the redundant warm-path timing test (P3)

- **Evidence:** `CombatFeedbackGlyphAtlasTests.swift:234-451` (`CombatFeedbackReferenceBaker`) re-derives production's layout constants (`horizontalPadding: 4, verticalPadding: 5, glyphSpacing: 8, shadowOffsetY: 1.5`, identical pointSize formula and origin advance) — the parity comparison moves in lockstep with production, so a coordinated change passes. `chipComposerWarmPathStaysUnderBudget` (`:92-129`) is a median-timing assertion that duplicates the raster-build coverage already forced by `CombatFeedbackRasterCatalogTests` and adds CI flake surface.
- **Fix:** pin golden `pointSize` values for the four chip samples and delete the baker, or delete the parity test; drop the warm-path timing test (raster build coverage lives in the catalog tests) or move it behind `BattlePerformance.xctestplan`.
- **Why this size:** a reference implementation that copies the implementation is a vacuous oracle; timing assertions belong in the dedicated performance plan.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature`.

---

## Execution notes

- **Ordering:** Phase 1 first (behavior), then 2, 3, 4. Each phase is independently verifiable and committable; do not mix phases in one commit.
- **Touched paths:** read `./Scripts/agent-context.sh --agent --paths <file...>` for each phase before starting it, per task routing.
- **Verification:** every phase ends with the listed `./Scripts/test-package.sh <Package>` runs; before any commit run `./Scripts/handoff.sh --isolate --paths <changed files...>`.
- **Change budget:** total expected direction is a net LOC reduction (mostly Phase 3/4) with +tests only for the Phase 1 behavior fixes; run `./Scripts/change-budget.sh` if any phase looks like growth.
- **Design decisions (propose-and-stop if product pushes back):** 1.3's UI-gating alternative for revive; the `SurfaceRole` case trimming if a preview/preview-factory depends on an unused case.
- **Non-goals (verified, intentionally not changed):** Whiplash's `takeRawDamage` bypass is documented as deliberate (stack-overflow guard in long sims) — flagged, not changed; `hasPendingControl` linger semantics are consistent with the enemy border-accent behavior and need a product/balance decision before touching conditionals; auto-battle's `guard await playCard(card) else { return }` terminates on transient failures but a bounded-retry change needs design input to avoid a spin risk.
