# Codebase improvement plan — round 2 (bugs, performance, simplification, tests)

Date: 2026-08-11
Status: Active execution plan (delete when finished)
Scope: Whole-repo exploration for confirmed improvement candidates across four categories. Every item was verified by reading the relevant code before inclusion; candidates that could not be confirmed are omitted.

Relationship to the existing plan: this is a complementary round 2. Items already owned by `2026-08-11-codebase-improvements.md` (Frostwarden freeze, Mystery stale choice, `.defeatedAlly` revive, Slice particle caching, `BattleFeedbackLane.pruneExpired`, `CombatFeedbackRasterPool.markMostRecent`, `CombatFeedbackFloatRecipe.idealCore`, `EnemyPowerMultipliers`, `BattlePresentationControlSkipTests`, Labyrinth adjacency dedup, Mystery XP pin, glyph baker) are **not** repeated here. One round-1 item is stale and superseded: round 1 §3.2 claims `AppEnvironment.battleTickInterval` field + parser exist and should be deleted — the current `AppEnvironment.swift` (145 lines) has no such field; the live version of that surface is round-2 §1.1 below.

Guiding rules applied: smallest change that removes the confirmed cause; prefer delete → reuse → simplify → parameterize; keep behavior-deterministic changes in `BattleEngine` with tests that fail on the old behavior; path-scoped verification before any commit.

---

## Phase 1 — Correctness fixes (do first)

### 1.1 Every UI test passes `-battle-tick-interval` but nothing parses it (P1, broken anti-flake contract)

- **Evidence:** `TrinketUITests/Support/TrinketUITestCase.swift:12-20` puts `"-battle-tick-interval", "1.0"` in `testLaunchArgs`, `:45-50` swaps `"0.01"` in via `allForBattle(fastTicks:)`, and `:110-130` `allForMidBattle()`/`replacingBattleTickInterval` swap in `"60"`; `BattleFlowUITests.swift:4-6` documents that 60 s ticks "keep the opening hand put and never race into live-tick resolution"; `AppPerformanceUITests.swift:154-157` uses it so stage 1-1 "must not resolve" during the measured transition. `AppEnvironment.parse` (`AppEnvironment.swift:58-91`) reads no `battle-tick` key — the only `ProcessInfo` reader besides it is `BattlePerformanceTiming.swift:10`. The battle's live cadence is `BattleSession.autoEndTurnDelay` (`BattleSession.swift:104`, default 0.4 s). So mid-battle tests race the 0.4 s auto-end while believing they hold 60 s ticks; `fastTicks` is dead code; `TrinketUITests/README.md:55`'s "3 s ticks" claims are wrong.
- **Fix (recommended):** implement the argument. Parse a `battleTickInterval: TimeInterval?` in `AppEnvironment`, thread it through `AppState`/`makeBattleRuntime` (`TrinketApp.swift:26-30`) into a new `autoEndTurnDelay` capability on `BattleRuntimeDependencies` (`BattleRuntimeDependencies.swift`), and pass it to `BattleSession(presentationEnvironment:)` (`TrinketApp.swift:27`). Default remains 0.4 s when absent. **Alternative (smaller surface, propose-and-stop):** delete the argument from the three launch-arg builders + helper functions, delete `fastTicks`, and correct the two README/header claims — accepting that mid-battle tests then must hold the opening hand some other way (the `-launch-screen battle-victory` pattern covers the victory side already).
- **Why this size:** the tests' own determinism contract is broken; restoring it is ~15 lines across AppEnvironment + dependencies + session init. Deleting is the fallback if product prefers no new launch surface.
- **LOC direction:** ~+15 (implement) or ~-20 (delete).
- **Test:** no new test for the arg itself; run the UI plans and confirm `BattleFlowUITests`/`SmokeBattleTests` no longer race (existing tests are the assertion).
- **Verify:** `./Scripts/test.sh smoke-full` (or the closest UI gate available in this environment).

### 1.2 `BattleState.restoreMana` discards its `sourceActorID` parameter (P2, dead-parameter masking a latent trigger)

- **Evidence:** `BattleState+Resources.swift:36` — `restoreMana(_:to:sourceActorID _: String)` explicitly ignores the source. All five callers (`RestorationHandlers.swift:53-57`, `CombatTriggerEngine+Resources.swift:66-70`, `AbilityMechanicHandlers.swift:138-141`, `BattleCardCombatEngine.swift:160`, `DamagePipelinePostSteps.swift:151`) pass a meaningful actor; the mana-gain reaction `afterGainMana` is fired with the *target* as source, so any source-based trigger is impossible and no code consumes the parameter.
- **Fix:** remove the parameter from `restoreMana` and all call sites. If a source-scoped mana reaction is ever needed, it belongs in the reaction firing site, not a dead parameter.
- **Why this size:** a parameter with zero readers is surface, per change discipline.
- **LOC direction:** ~-6.
- **Verify:** `./Scripts/test-package.sh BattleEngine` (mana-gain reaction tests must stay green).

### 1.3 `recordAction` always returns an empty array (P3, dead return surface)

- **Evidence:** `BattleTurnEngine.swift:395-404` increments `actionCount`, marks the actor, then `return []`. All three callers (`:23`, `:42`, `:98`) `append(contentsOf:)` the always-empty result.
- **Fix:** make it `Void`; drop the `@discardableResult` and the empty-array appends at the call sites.
- **Why this size:** no behavior change; removes a lie in the signature.
- **LOC direction:** ~-4.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 1.4 `CombatBuildResolver` traps on duplicate inventory item IDs (P3, latent crash)

- **Evidence:** `CombatBuildResolver.swift:12` — `Dictionary(uniqueKeysWithValues: inventory.map { ($0.id, $0) })` is a runtime trap if two inventory items share an `id`; the equipped-items lookup at `:13-16` would silently work if built first-wins.
- **Fix:** `Dictionary(inventory.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })`.
- **Why this size:** one-line hardening of a latent crash; no behavior change for the well-formed input.
- **LOC direction:** ~0.
- **Verify:** `./Scripts/test-package.sh BattleEngine` (build resolver tests unchanged).

### 1.5 `LabyrinthMapView.onAppear` swallows the `labyrinth.enter()` failure message (P2, inconsistent error handling)

- **Evidence:** `LabyrinthMapView.swift:71-75` — `.onAppear { _ = labyrinth.enter() }` discards the returned `StageMapMessage?`, while the empty-state Enter button at `:129-136` correctly does `if let message = labyrinth.enter() { nodeMessage = message }`. A deep-linked entry (the `-launch-screen labyrinth-map` path used by `PlayModeNavigationUITests.swift:30`) silently drops the entry-failure explanation.
- **Fix:** use the same `if let message = …` pattern in `onAppear`.
- **Why this size:** same-file consistency; one guard replaces the discard.
- **LOC direction:** ~+2/-1.
- **Verify:** `./Scripts/test-package.sh TrinketAppState` (app-level) or path-scoped app verification per `Docs/AgentContext`.

### 1.6 Ability `.abilityDamage` log event under-reports multi-target damage components (P2, wrong combat log / floating text)

- **Evidence:** `BattleTurnEngine.swift:231-252` emits the `.abilityDamage` component event only for `component.target == .abilityTarget`, and the ability summary event at `:82-96` sums only `totalDealtToAbilityTarget`. A component targeting `.hero`/`.companion`/`.enemy` deals pipeline damage with no log/floating text, so a multi-component ability shows less damage than it dealt.
- **Fix:** emit the `.abilityDamage` event for every resolved component (append to `resolvedComponents` regardless of target), and include all component damage in the summary `amount`.
- **Why this size:** corrects observability, not combat math; no balance change.
- **LOC direction:** ~+4/-2 + 1 test.
- **Test:** `BattleEngineTests` — an ability with a `.abilityTarget` damage component plus an `.enemy` component; assert two `.abilityDamage` events and the summary amount equals the sum.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 1.7 `nextHolyStrike` burn applies the doubled amount twice (P2, ~4× authored damage — design decision)

- **Evidence:** `BattleTurnEngine.swift:206-208` doubles `amount` (`amount *= 2`) when consuming Next Holy Strike, then `:254-262` calls `applyDecayingDoT(keyword: .burn, potency: amount, …, dealImmediateDamage: true)` with that already-doubled value — dealing the doubled burn again immediately. A 10-damage holy strike becomes 20 holy + 20 immediate burn + a 20/turn burn stack.
- **Fix (default recommendation):** pass the pre-doubling amount to the burn potency so the igniter equals the authored component damage (matches the "burn potency == damage dealt" convention for base ability damage elsewhere). **Alternative:** keep potency at the doubled value but set `dealImmediateDamage: false`. This is a balance-affecting decision — **propose-and-stop** with product before landing either.
- **Why this size:** one of two one-line adjustments; the test pins the chosen semantics.
- **LOC direction:** ~0 + 1 test.
- **Test:** `BattleEngineTests` — ability with `nextHolyStrike` active on a damage component; assert the applied burn potency and immediate burn damage match the chosen convention (test fails on today's 4×).
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 1.8 Small correctness bundle (P3 — each gated on `rg` re-confirmation at execution time)

- `PlayerState.item(matching:)` (`PlayerState.swift:24-30`) falls back to a *different* item by `templateID` when the exact ID is missing (salvaged/corrupted); used by `equippedItem` (`:344-350`) and UI, so corruption renders the wrong item instead of nothing. Change: return `nil` on exact-ID miss; make any template fallback explicit at call sites.
- `BattleLoot.swift:74,79` — `bases.randomElement(…) ?? bases[0]` traps if the catalog is empty (everywhere else in the codebase guards emptiness). Change: `guard let base = … else { fail closed }`.
- `RosterHydration.swift:16-23` — stale active-hero fallback is `unlockedHeroIDs.first` (arbitrary `Set` element); the resolved active hero can differ between launches. Change: fall back to the lowest catalog-order unlocked ID (mirror `orderedCollectionCombatants`).
- `ItemCorruption.swift:80-81` — `eligible.sorted(by:).randomElement(using:)`; the sort has no effect. Change: drop `.sorted(by:)`.

---

## Phase 2 — Performance

### 2.1 `CombatFeedbackChipBridge.updateAvailabilityWakeTime` scans every item on every publish (P2)

- **Evidence:** `CombatFeedbackChipBridge.swift:100-110` iterates `itemsByTarget.values` × items on **every** `publish` (each card play, each chip removal, each reset) purely to nudge a timer's fire date, even when only a handful of items changed. Long battles accumulate hundreds of chips.
- **Fix:** track `nextAvailabilityDate` incrementally — after a publish, consider only the newly inserted items and the previously scheduled date (or scan only the affected targets from the publish switch).
- **Why this size:** the whole publish path is O(changed) instead of O(total); no timer semantics change.
- **LOC direction:** ~+6/-4.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature` (availability-timer tests unchanged).

### 2.2 Status-effect overlay runs a full-rate `TimelineView(.animation)` for the entire status lifetime (P2)

- **Evidence:** `CombatantCardStatusEffectVariants.swift:301-338` mounts `TimelineView(.animation)` and keeps ticking at refresh rate for as long as stun/freeze is active (many turns), recomputing `CombatantStatusCardTransform` + `CombatantStatusEffectOverlay` (a Canvas redrawing up to 40 snowflakes) every frame. The comment at `:306-307` confirms progress is meant to saturate (intro-only phase), and unlike `CombatantSliceEffect`/`BattleDissolveArtwork` there is no clock teardown — `progress` climbs unbounded.
- **Fix:** once the phase saturates (e.g. `progress >= 1`), pause the clock — `TimelineView(.animation(paused: true))` — or switch to a non-animating branch that renders the saturated overlay once, mirroring `CardCastOverlay.swift:147`'s paused-while-idle pattern.
- **Why this size:** bounded display work per affected combatant; visual output identical after the ~4 s intro.
- **LOC direction:** ~+5/-2.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature` + `./Scripts/test.sh unit` (battle smoke path unchanged).

### 2.3 `PlayerSaveSanitizer.adjacentPath` recomputes `nodeIDs.sorted()` inside the BFS loop (P3)

- **Evidence:** `PlayerSaveSanitizer.swift:408` — `nodeIDs.sorted()` is loop-invariant but runs per node popped from the frontier → O(V² log V); exercised on every save of a migrated Labyrinth save (`ensureHistoricalFloorAccess`).
- **Fix:** hoist `let sortedNodeIDs = nodeIDs.sorted()` before the loop.
- **Why this size:** one-line hoist; identical output.
- **LOC direction:** ~0.
- **Verify:** `./Scripts/test-package.sh TrinketPersistence`.

### 2.4 `BalanceStatsAggregator.summarize` re-filters the full record set once per tier (P3)

- **Evidence:** `BalanceStatsAggregator.swift:78-84` — `report.config.tiers.map { report.records.filter { $0.tier == tier } … }` runs a full scan + allocation per tier (O(tiers × records)) over thousands of sweep records.
- **Fix:** `Dictionary(grouping: report.records, by: \.tier)` once, then index per tier.
- **Why this size:** one grouping replaces N passes; report output unchanged.
- **LOC direction:** ~+2/-2.
- **Verify:** `./Scripts/test-package.sh BattleEngine` (aggregator tests unchanged).

### 2.5 `FightPacing.paced` recomputes `poolMetrics` twice plus a content lookup per call (P3, hot path)

- **Evidence:** `FightPacing.swift:99-129` — `multiplier` → `clockMultiplier` → `scheduleClockBonus` calls `poolMetrics`, and `comebackMultiplier` calls it again; `BattleState+Pacing.swift:11` `isBossEnemy` does a `GameContent.enemy(matching:)` dictionary lookup per call. `paced()` runs per damage component, block gain, heal, and control-meter charge — dozens of times per round and thousands of battles in balance sweeps.
- **Fix:** compute `poolMetrics` (and boss-ness) once per `paced(_:sourceActorID:)` invocation and pass down; or cache `isBossEnemy` on the battle state.
- **Why this size:** removes ~3× redundant deterministic work in the hottest sim path without behavior change.
- **LOC direction:** ~+5/-5.
- **Verify:** `./Scripts/test-package.sh BattleEngine` (pacing tests assert identical multipliers).

### 2.6 `toPlayerInventoryState` linear catalog scan per item on save-graph load (P3)

- **Evidence:** `PlayerSaveModelMapping.swift:278` — `GameContent.itemBaseTypes.first(where: { $0.id == item.baseTypeID })` per item during `toPlayerInventoryState()`; same pattern for affix lookups in `ItemCorruption.swift:144,187,194`. The codebase already builds `[String: …]` index tables elsewhere (`GameContent.swift:8-14`, `RosterHydration.swift:6-8`).
- **Fix:** build a `[String: ItemBaseType]` index once per hydration and look up.
- **Why this size:** matches the established index pattern in the same package; O(items + catalog) instead of O(items × catalog).
- **LOC direction:** ~+4/-2.
- **Verify:** `./Scripts/test-package.sh TrinketPersistence` (read/write survival tests unchanged).

---

## Phase 3 — Remove dead / over-engineered surface

### 3.1 Delete `primaryStatOverrides` persistence plumbing that is never written (P1)

- **Evidence:** `PlayerState.swift:80,91,101,189` and `PlayerSaveModelMapping.swift:55-62,193-207,230-241` — repo-wide grep shows the only writes are the default `[:]`; it is persisted as SwiftData `PrimaryStatsModel` rows, reconciled on every roster save, hydrated back, then read in `configuredCombatant` (`PlayerState.swift:189`) where it is always a no-op.
- **Fix:** remove the property, its `PlayerSaveGraph` mapping functions, and the `PrimaryStatsModel` rows in the save graph mapping (keeping the schema/migration behavior of the surrounding save intact — verify the `update:`/`make:` paths no longer reference it).
- **Why this size:** ~50 lines of mapping + a persisted table + per-save reconcile work that can never do anything; the repo's change discipline explicitly prohibits predicted-future-reuse abstractions.
- **LOC direction:** ~-50.
- **Verify:** `./Scripts/test-package.sh TrinketPersistence` (read/write survival across reload must still pass) and `./Scripts/test-package.sh TrinketAppState`.

### 3.2 Dead mana-cost system advertises costs never charged (P1, product-facing lie — design decision)

- **Evidence:** `BattleTurnEngine.swift:60-62,121-128` only spends mana inside `if spendMana`, and both production callers pass `spendMana: false` (`BattleCardCombatEngine.swift:77,228`) — `rg "spendMana: true"` returns nothing. Dead as a result: `spendManaIfNeeded`, `CombatModifierProfile.effectiveManaCost`/`manaCostReductionPercent` (`CombatModifierProfile.swift:23,111,142-147`), and the reduction affixes (`AffixModifier+CombatProfile.swift:75-76`). Meanwhile `AbilityDescriptionFormatter.swift:32-34` renders "costs N Mana" for any `manaCost > 0`, and `BattleCardCombatTests.swift:330` pins that the cost is never enforced. Only the empowerment spend (`spendManaToEmpowerBurnOrFreezeIfNeeded`) consumes mana.
- **Fix (default recommendation):** delete the dead spend path and reduction plumbing, and stop advertising costs in `AbilityDescriptionFormatter` (render nothing for mana cost). **Alternative (propose-and-stop):** wire `playCard` to actually spend `effectiveManaCost` — a balance change requiring product sign-off.
- **Why this size:** two equal options; deletion is the smallest change consistent with "no caller passes true" and fixes the player-facing lie.
- **LOC direction:** ~-40 (delete).
- **Verify:** `./Scripts/test-package.sh BattleEngine` and `./Scripts/test-package.sh TrinketContent` (ability description formatting tests updated to the chosen behavior).

### 3.2b Note: `PlayerSaveStore` slice setters swallow persistence failures (P2, data-integrity — design decision)

- **Evidence:** `PlayerSaveStore.swift:326-339` (`mutate`) catches every error, records `lastPersistenceError`, and returns normally; public setters (`:54-82`) return `Void`. With `persistSaveImmediately` off by default (`AppEnvironment.swift:82`), a disk failure silently discards the caller's mutation (`BattlePartyInlinePicker.swift:161,226` calls `playerSave.roster = roster`). 
- **Fix (propose-and-stop):** make the setters `@discardableResult` returning `Bool` (like `persistBatch`) so callers can surface "couldn't save progress," or route mutations through the existing throwing path. Defer UI surfacing to product.
- **Why this size:** restores a failure signal without changing the save graph.
- **LOC direction:** ~+8/-2.
- **Verify:** `./Scripts/test-package.sh TrinketPersistence`.

### 3.3 `BattleHandMotionConfiguration` ships nine "experimental / unused by production hand path" tunables (P2)

- **Evidence:** `BattleHandMotionConfiguration.swift:88-98` defines `pickupResponse/pickupDamping/readinessResponse/readinessDamping/cardCommitResponse/cardCommitDamping/impactResponse/impactDamping/cardMaximumStretch`, self-labeled "Experimental / unused by production hand path"; they participate in the hand-written `==` at `:203-218` evaluated by `BattleHandView`'s `.animation(value:)` on every layout change, and `TrinketMotion.swift:82` (`cardMaximumStretch`) exists only to seed one of them. Grep confirms zero readers.
- **Fix:** delete the nine fields, their `handSpringFieldsEqual` branches, and `TrinketMotion.Battle.cardMaximumStretch`.
- **Why this size:** nine dead tunables plus Equatable work per layout pass; speculative surface the change discipline discourages.
- **LOC direction:** ~-25.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature` + `./Scripts/test-package.sh TrinketDesignSystem`; grep `cardMaximumStretch` empty.

### 3.4 `ultimateFallbackHold` is dead and its `max()` is constant-folded (P2)

- **Evidence:** `UltimateCinematicOverlay.swift:159-172` computes `max(ultimateFallbackHold(4.0), ultimateVideoWatchdog(12.0))` — always 12.0; the no-video and `whenReady == false` branches (`:123-128`, `:137-139`) call `onAutoFinish` immediately, so the art-fallback hold never exists. The only other reference is `TrinketMotionTests.swift:10` asserting `watchdog > fallbackHold`.
- **Fix:** use `ultimateVideoWatchdog` directly; delete `ultimateFallbackHold` and the misleading `max`. If product wants the art-fallback hold, apply it in the `whenReady == false` path instead — **propose-and-stop**.
- **Why this size:** removes a constant-folded no-op and the false impression the fallback exists.
- **LOC direction:** ~-8.
- **Verify:** `./Scripts/test-package.sh TrinketDesignSystem`.

### 3.5 `ChipChromeRole.compact` is a dead case with dead padding metrics (P3)

- **Evidence:** `CombatFeedbackMotion.swift:22` declares `.compact`; production callers of `trinketGlassChip` pass `.emphasis` (`ShopEncounterView.swift:188`), `.utility` (`SkillCalloutView.swift:75`), or the default `.standard`; the `.compact` padding branches in `VisualFoundation.swift:283-284,292-293` have no caller.
- **Fix:** remove the case and its two padding branches.
- **Why this size:** dead public API case + dead layout constants.
- **LOC direction:** ~-6.
- **Verify:** `./Scripts/test-package.sh TrinketDesignSystem` + grep `.compact` empty in production.

### 3.6 `CombatFeedbackRasterPool.seedForTesting` ships test-only surface in production (P3)

- **Evidence:** `CombatFeedbackRasterPool.swift:334-369` — a production-file extension whose sole purpose is seeding rasters without the UIKit bake; used only by `CombatFeedbackRasterCatalogTests.swift:37,50,56,76`. It increments `buildCount`/`rasterAllocationCount` and participates in LRU, so its accounting can mask warm-path behavior in diagnostics.
- **Fix:** move it to a `#if DEBUG` test hook (or a testable seam) so tests keep using it without shipping the API; if that fights the pool's concurrency posture, have tests drive the existing `prepare` path against a stubbed atlas instead.
- **Why this size:** removes production-module test surface; keeps catalog test coverage.
- **LOC direction:** ~0 (relocation).
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature` (raster catalog tests unchanged).

### 3.7 `BalanceStatsAggregator` dead private helpers (P3)

- **Evidence:** `BalanceStatsAggregator.swift:365-373` — `private static func winRate(_:)` and `average(_:)` have zero callers (rates computed inline).
- **Fix:** delete both.
- **Why this size:** dead helpers.
- **LOC direction:** ~-9.
- **Verify:** `./Scripts/test-package.sh BattleEngine`.

### 3.8 `CollectionView` / `InventoryGridView` duplicate the entire salvage-detail state machine (P1, app-side duplicate)

- **Evidence:** both declare identical `@State` (`selectedItem`, `selectedItemIndex`, `dissolvingTombstone`, `salvageSuccessCount`): `CollectionView.swift:13-18`, `InventoryGridView.swift:38-41`; both implement the same `.sheet(item:)` + `ItemDetailView.inventorySalvageDetail` + tombstone re-insert (`CollectionView.swift:40-66`, `InventoryGridView.swift:99-115`), the same dissolving-cell branch (`:137-149`, `:52-60`), and `finishSalvageDissolve()` (`:177-181`, `:123-127`). The copies have already drifted: Collection resolves the dissolve index from `selectedItemIndex`/full-inventory `firstIndex` while Inventory re-derives from the filtered list.
- **Fix:** extract one shared salvage-detail controller (an `@Observable` with the four pieces of state + sheet wiring + dissolve re-insert + `finish`) or a shared `SalvageItemDetailSheet` view; both screens become thin wrappers. Single owner for index math, dissolve timing, and haptics.
- **Why this size:** a confirmed duplicate per the change discipline ("parameterize a confirmed duplicate"); one behavior owner replaces two drift-prone copies.
- **LOC direction:** ~-60 net.
- **Verify:** path-scoped verification for the two screens plus `./Scripts/test.sh smoke-full` (Collection smoke path unchanged).

---

## Phase 4 — Test optimization / CI

### 4.1 `Integration.xctestplan` auto-includes the whole UI target; random ordering; undocumented (P2, silent PR-vs-nightly coverage asymmetry)

- **Evidence:** `Integration.xctestplan:12-24` declares the `TrinketUITests` target with only `skippedTests` (the two performance classes) — no `automaticallyIncludesTests: false`, no `selectedTests` — while `Smoke.xctestplan` and `FullUI.xctestplan` both opt out. `Scripts/test.sh:253` maps `test.sh all` to Integration; `nightly.yml:65` runs it. A new UI test class is invisible to the PR smoke/fullUI gates but runs in nightly, in random order (`Integration.xctestplan:10` `"random"` vs all four other plans `"alphabetical"`), and the README plan table (`TrinketUITests/README.md:6-13`) doesn't list Integration at all.
- **Fix:** give Integration an explicit `selectedTests` list (or `automaticallyIncludesTests: false`); switch `testExecutionOrdering` to `alphabetical`; add the Integration row to the README table. Optionally add a CI guard (natural home: `Scripts/assert-generated-output.sh`) asserting every `TrinketUITests` class appears in exactly one of Smoke/FullUI/Integration.
- **Why this size:** closes the silent coverage gap without changing which tests run.
- **LOC direction:** ~+20 (plan JSON + guard) / no test code.
- **Verify:** `./Scripts/test.sh smoke-full` and the nightly-equivalent command in this environment.

### 4.2 Tautological XP tests re-derive the production formula (P2)

- **Evidence:** `ExperienceScalingTests.swift:51-57` — `expected = max(1, Int((Double(baseAward) * catchUp).rounded()))` where `baseAward = battleAward(...)` and `catchUp = catchUpMultiplier(...)` — the verbatim body of `battleAwardWithCatchUp` (`ExperienceScaling.swift:64-67`); `:60-69` asserts `equalBattleAward(...) == battleAwardWithCatchUp(playerLevel: enemyLevel: playerLevel)` — an identity, since `equalBattleAward` is a one-line wrapper (`:71-77`). A formula regression moves both sides and stays green.
- **Fix:** pin concrete values for representative level pairs (matching the existing `award == 67` style at `:31`), or assert invariants against independently computed expectations.
- **Why this size:** converts self-referential assertions into behavior pins.
- **LOC direction:** ~-10/+2.
- **Verify:** `./Scripts/test-package.sh TrinketCore`.

### 4.3 Tautological Labyrinth stipend test (P3)

- **Evidence:** `LabyrinthProgressTests.swift:456-494` (`depthFiveCompletionGrantsNoMilestoneBonus`) computes `expectedGold` via `LabyrinthCompletion.nonCombatGoldStipend(...)` — the exact production function under test — then asserts completion granted that amount. The sibling `gildedWhisperTruncatesPositiveGoldBonus` (`:266-279`) pins `== 3` and is the correct style.
- **Fix:** pin the literal stipend value for the depth-5 case (e.g. `gold == goldBefore + 7`).
- **Why this size:** same test file already demonstrates the pinned-value style.
- **LOC direction:** ~-2.
- **Verify:** `./Scripts/test-package.sh TrinketPersistence`.

### 4.4 Triple-covered per-target stream-stagger invariant + duplicated fixtures (P2)

- **Evidence:** `BattleSessionSimulationTests.swift:271-303` (`feedbackVisualsUseIndependentPerTargetStreams`) and `:305-325` (`feedbackVisualsQueueEveryDistinctChipInRapidSequence`) plus `BattleSessionPartyFeedbackStreamTests.swift:424-455` (`partyFeedbackUsesOneIndependentStreamPerCombatant`) all assert the identical invariant — `availableAt == now + stagger × index` per target. The fixture helpers `feedbackEvent` (`:392-410`) and `partyFeedbackEvent` (`:457-475`) are byte-for-byte duplicates differing only in a default keyword.
- **Fix:** keep one test covering per-target independence + sequential stagger, parameterized over both fixture cases; delete the duplicate helpers.
- **Why this size:** three copies of one behavior is duplicate coverage; the parameterized survivor keeps both stream kinds covered.
- **LOC direction:** ~-60 test.
- **Verify:** `./Scripts/test-package.sh TrinketBattleFeature`.

### 4.5 Duplicated `PlayerSave` fixture builders across test files (P3)

- **Evidence:** `StageRewardTests.swift:16-31`, `BattleLootTests.swift:88-96`, `MysteryEffectApplierTests.swift:8-18` and `:254-264` each hand-build the same `PlayerSave(...)` with the same defaults; `ShopPurchaseApplierTests.swift:124-135` and `ItemSalvageApplierTests.swift:113-127` parallel `makeItem`/`makeOffer` builders. `TrinketPersistenceTestSupport/SaveTestSupport.swift` exists precisely as the shared fixture host.
- **Fix:** add `makeSave(...)`/`makeItem(...)` variants to `SaveTestSupport` and delete the per-file copies.
- **Why this size:** fixture drift — when a `PlayerSave` field or default changes, four places update; one shared host is the established owner.
- **LOC direction:** ~-40 test.
- **Verify:** `./Scripts/test-package.sh TrinketPersistence`.

### 4.6 `ShopFlowUITests` re-verifies the shop shell catalog `SmokeShopTests` already owns (P2)

- **Evidence:** `ShopFlowUITests.swift:18-25` asserts the `leaveButton` and the offer-card query with the comment "Shell catalog (title/gold/leave/offers) lives in SmokeShopTests; wait once then journey"; `SmokeShopTests.swift:14-23` asserts the same shell. Both launch with identical `allForShop() + completedStages([…])`. This duplicates the same interaction across smoke and exhaustive UI, which `TrinketUITests/README.md:26` and `Docs/Platform/Testing.md:114` prohibit.
- **Fix:** in `ShopFlowUITests`, drop the `leaveButton` and explicit offer-card existence checks; wait directly on the first offer card and start the purchase journey.
- **Why this size:** removes a redundant wait cycle in the slow suite; smoke remains the owner.
- **LOC direction:** ~-6 test.
- **Verify:** `./Scripts/test.sh smoke-full`.

### 4.7 `AppPerformanceUITests` copy-pastes journey setup and defeats `measure` (P2)

- **Evidence:** `AppPerformanceUITests.swift:76-94` (`test03HomesteadDetailTransition`) is a verbatim copy of the Farming→Wheat Field setup from `TabNavigationUITests.swift:105-118` — including the same comment — so the measured scenario can drift from the journey it claims to measure. `test00ColdLaunchToPlay` (`:29-37`) sets `options.iterationCount = 1` on `XCTApplicationLaunchMetric`, so the "launch performance gate" is a single noisy sample (and the trailing `app.terminate()` inside a metric that manages launch is dead work).
- **Fix:** extract one `HomesteadScreen` helper (e.g. `openFarmingCategoryAndRevealWheatFieldNode`) into `Support/Screens/TabBar.swift` and call it from both tests; drop `iterationCount = 1` (accept ~5 cold launches in the nightly perf plan) or delete the single-sample test and rely on the frame-metrics path used by the other scenarios.
- **Why this size:** one shared navigation helper + reverting a measure-machinery defeat; no behavior change to the app.
- **LOC direction:** ~+8/-14 test.
- **Verify:** `./Scripts/test.sh` performance plan in this environment (or defer to nightly if not runnable locally).

### 4.8 `SmokeCollectionTests` negative assertions can pass before the hierarchy settles (P3, flake)

- **Evidence:** `SmokeCollectionTests.swift:16-23` waits only on the `heroesCategory` button then asserts `XCTAssertFalse(inventoryCategory.exists)` / `XCTAssertFalse(inventoryEmptyState.exists)`; the negatives can be green simply because the scroll content hasn't rendered yet.
- **Fix:** after `assertLoaded`, wait for a stable shell marker (the collection `ScrollView` or a known hero shelf card) before asserting the two negatives.
- **Why this size:** removes a classic false-green with one wait; keeps the fresh-start-hides-inventory assertion meaningful.
- **LOC direction:** ~+3 test.
- **Verify:** `./Scripts/test.sh smoke-full`.

---

## Execution notes

- **Ordering:** Phase 1 first (behavior), then 2, 3, 4. Each phase is independently verifiable and committable; do not mix phases in one commit.
- **Touched paths:** read `./Scripts/agent-context.sh --agent --paths <file...>` for each phase before starting it, per task routing.
- **Verification:** every phase ends with the listed `./Scripts/test-package.sh <Package>` runs; before any commit run `./Scripts/handoff.sh --isolate --paths <changed files...>`.
- **Change budget:** net LOC reduction overall (mostly Phases 3/4) with +tests only for Phase 1 behavior fixes; run `./Scripts/change-budget.sh` if any phase looks like growth.
- **Design decisions (propose-and-stop if product pushes back):** 1.1 implement-vs-delete for the tick argument; 1.7 `nextHolyStrike` burn convention; 3.2 wire-vs-delete the mana-cost system; 3.2b surfacing save failures; 3.4 `ultimateFallbackHold` art-hold behavior.
- **Non-goals (verified, intentionally not changed):** Whiplash's `takeRawDamage` bypass in `CombatTriggerEngine+Defense.swift:245` remains flagged-but-not-changed — round 1 already documented it as a deliberate stack-overflow guard for long balance sims; round 2 re-verified and agrees. `CombatFeedbackRasterPool.markMostRecent`/`BattleFeedbackLane.pruneExpired`/Slice particle caching remain owned by round 1. `CombatFeedbackFloatRecipe` (whole enum dead) is subsumed by round 1 §3.1's recipe cleanup — do not split ownership.
