---
type: execution-plan
status: cancelled
created: 2026-08-27
updated: 2026-09-01
expires: 2026-09-10
---

# SimplificationConsolidationRound2

## Objective
Repo-wide simplification: collapse duplicated ownership (motion, card artwork, damage ordering), delete empty `TrinketBattleRuntime` package, harden saves (immediate durability, frozen mystery preview, auto-rebuild labyrinth), and fix build/codegen duplication — without giving up frame budget. Performance is first priority; no VoiceOver work.

Locked decisions: save immediately (no 300ms deferred), mystery preview frozen via ticket, labyrinth corrupt blob auto-rebuilds, damage numbers keep atlas (perf-first), runtime seam foundation-owned (`BattleEngine` owns `BattleRuntime` contract).

## Plan

### Phase 1 — Safe deletions & single ownership (no gameplay change)
- [x] **1.1 BattleMotion single owner.** Delete `Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/BattleMotion.swift` shim (40+ forwarding getters). *Done 2026-08-27:* shim was dead (0 consumers used `BattleMotion`, all 158 sites used `TrinketMotion.Battle` directly). Deleted file, updated `TrinketMotion.swift` header to remove shim reference. Verified `TrinketDesignSystem` 17 tests pass.
- [x] **1.2 Delete TrinketBattleRuntime package.** `Packages/TrinketBattleRuntime` (<150 LOC, 3 deps, XcodeGen target). *Done 2026-08-27:* Copied `BattleRuntime.swift`/`BattleRuntimeDependencies.swift`/`BattleRunConfiguration.swift`/`BattleRunKey.swift`/`BattlePerformanceScenario.swift` into `BattleEngine` (deleted `import BattleEngine` self-import, added `EntropyCheck: allow` for `UUID()`), replaced 42× `import TrinketBattleRuntime` → `import BattleEngine` (TrinketApp, Play features, BattleFeature, AppState, tests), removed `TrinketBattleRuntime` from `Packages/*/Package.swift` and `project.yml` and `Scripts/swift-source-dirs.env` (`SWIFT_SOURCE_DIRS` + `TRINKET_COMPILE_ONLY_PACKAGES`). `generate.sh` + `BattleEngine 407 tests` pass. Net -1 package target.
- [ ] **1.3 Card artwork primitive.** `BattleAbilityCardFace` vs `ProductCardShell` duplicate 3:4 shape/surface/stroke/prepared-art/placeholder. *Deferred:* low player impact, batch with Phase 4 polish. Minimal win only; no drawback if skipped now. Will extract `CardArtwork` primitive shared by both when doing 4.x.
- [x] **1.4 PreparedArtworkCache fix.** *Done 2026-08-27:* Added `inFlightNames: Set<String>` coalescing to `PreparedArtworkCache.decode` (avoids duplicate decodes when `BattleCastPrewarmLane` + `PreviewLabView.warmArtwork()` race), fixed `decode` filter to skip `inFlightNames` and `defer` cleanup, fixed pin lifecycle (documented no-op branch for `nil` image), added `DEBUG assert limit >=160 MiB` in `configureImageBudget`, expanded `BattleCastPrewarmLane` from `hand.first` single pin to full hand (`compactMap` all `ability.artReference?.imageName`), changed `BattleCastPrewarmKey` from `artworkName: String?` to `artworkNames: [String]`, fixed `TrinketMotion.swift` header. Verified `TrinketFeatureSupport 44 tests` pass.

### Phase 2 — Persistence correctness (highest player value)
- [x] **2.1 Save-immediate single source.** *Done 2026-08-27 (incremental):* Changed `PlayerSaveStore.init(persistSaveImmediately: Bool = false)` → `true` default, changed `AppEnvironment.parse` `persistSaveImmediately: arguments.contains("-persist-save-immediately")` → `!arguments.contains("-defer-persistence")` so production defaults to immediate saves (no 300ms `Task.sleep` coalescing). Deferred path retained for tests that explicitly pass `persistSaveImmediately: false`. Player promise: what you see on screen is already on disk; backgrounding cannot leave map/inventory mismatched. Full `observed*` deletion deferred to follow-up (keeps diff small, retains `flushPendingPersistence` no-op path).
- [x] **2.2 Frozen mystery ticket + auto-rebuild labyrinth.** *Done 2026-08-27 (partial):* `LabyrinthProgress.ensureMap(seed:eligibleRecruitEventIDs:)` now auto-recovers corrupt blobs: `if isMapPayloadUnreadable { isMapPayloadUnreadable=false; if hasMap {return} }` + fixed `resolvedSeed` to treat `seed==0` as nil (so `save.worldSeed==0` falls back to `labyrinth.worldSeed` instead of blocking generation). `PlayerSaveStore` + `PlayerSaveLabyrinthMigration.sanitizeLabyrinth` keep early return for unreadable (so `sanitize` still preserves blob for reload survival), but `LabyrinthCompletion.enter` (which calls `ensureMap` with `save.worldSeed`) now rebuilds instead of looping `StageMapMessage("Labyrinth Error")`. Updated `LabyrinthSaveRecoveryTests`: `enterDoesNotRebuildUnreadableMap` now expects rebuild (`hasMap` true, `!isMapPayloadUnreadable`, `worldSeed!=0`), `storeReloadThenEnterPreservesCorruptMapBlob` now expects after-enter `hasMap` true (was `false`). Fixed `corruptMapPayloadKeepsBlobAndDoesNotSanitizeRebuild` preserved (sanitize still keeps blob). Verified `TrinketPersistence 225 tests` pass. Remaining frozen mystery ticket (`PinnedMysteryStore` token for `installPreviews` vs `resolvedEncounterLevel`) deferred to follow-up — preview currently still diverges if `pinMysteryEventIfNeeded` fails.
- [x] **2.3 Gold/equipment single owner.** *Verified 2026-08-27:* `PlayerRosterState.maxGoldBalance=999` + `clampedGoldBalance` is already single source; `PlayerSaveSanitizer.sanitizeRoster` and `sanitizeHomestead` already use it. No drift found; no change needed. Remains authority.

### Phase 3 — Battle engine perf & grouping
- [ ] **3.1 DamagePipeline single file + snapshot.** *Deferred to follow-up:* 7 `package extension DamagePipeline` files, order via comments, each step rescans `activeEffects/modifiers`; `BattleState.partyTriggers` + `CombatTriggerEngine.livingPartyTriggers` re-merge per access. Collapse 8→1 with `private static` steps, introduce `DamageResolutionSnapshot` built once (status flags + precomputed bonuses), single source `maxDrawAndPlayDepth 10`, deterministic ordering regression test.
- [ ] **3.2 BattleState budgets + TalentState grouping.** *Deferred to follow-up:* `BattleState` 18 vars/4 depths, `TalentState` 25 pending fields via `@dynamicMemberLookup` + `TalentBox` COW, `maxMana` recomputes per step. Group into `DodgePending/CardPending/ManaPending/LeechPending`, remove COW, cache `maxMana` in snapshot, make `ReactionScope.capHit` observable.
- [ ] **3.3 Trigger grouping via codegen.** *Deferred to follow-up:* `CombatTriggerEngine` +14 extensions + `CombatTraitTriggers` ~150 fields, `if triggers.X>0 { applyBlock }` ×40. Generate grouped structs from `trigger_family_schema.json`, extract `applyBlockIf` helper, exhaustive field-exercise gate.

### Phase 4 — Content/codegen & build polish + perf-safe feedback
- [ ] **4.1 Codegen parser table.** *Deferred to follow-up:* `content_codegen.py _MODIFIER_SIMPLE + triggers_swift` 90+ `startswith` duplicate JSON schema. `publicize` brace-counts only `//`/`"`; `swift_escape` double-escapes. Generate `TRIGGER_TOKEN_MAP` from schema, emit `public` in templates, delete `publicize`, fix `swift_escape`.
- [ ] **4.2 Build avoidance + stamp.** *Deferred to follow-up:* `generate.sh` unconditional `content_codegen.py`; `AbilityInventoryDump swift run` builds SPM even when only `project.yml` changed; duplicate stamp in `build-inputs.sh`/`run-env.sh`/`assert-generated-output.sh`. Cache binary, skip `swift run` when mtimes unchanged, unify stamp into `Scripts/lib/generation-stamp.sh`.
- [ ] **4.3 CombatFeedback perf-safe dedup (no VoiceOver).** *Deferred to follow-up — perf-first, no VoiceOver:* Keep atlas. Delete `MotionSampler` forwarder, collapse `statusChipLayouts`/`ChipChromeRole`, fix `AggregationKey` to combine same-keyword regardless of critical (perf win, fewer layers), delete dead `.buff` classify path. Skip AX tree per decision.
- [ ] **4.4 BattleView lane extraction.** *Deferred to follow-up:* `BattleView.swift:515` 5 private lanes capturing `BattleSession`; 6 interacting hand knobs; `syncAutoLift` keys on `card.id` vs `ability.id` (wrong lift with duplicates); celebrate ID collision. Extract lanes, single `HandInteractionConfig`, fix IDs to `card.id` + monotonic counter.

## Non-goals / untouched
- Hitch-prevention budgets: 320 MiB artwork / 550 MiB process / 260 MiB cache cap `physicalMemory/24` floor 160 — not lowered (AGENTS guardrail)
- Launch/imminent artwork pins kept
- `ItemAffixCatalog` chunking stays as type-checker workaround
- No VoiceOver for feedback chips

## Verification
Each phase lands via `handoff.sh --isolate --paths <touched>` + `ci-gate.sh --fast`. Full `test.sh unit` before push. Smoke targeted where UI touched; exhaustive UI CI-owned. `change-budget.sh` expected net-negative on deletions.

## Notes
Durable rules fold into `Docs/Platform/*`, package `README.md`, or `AGENTS.md` on completion. Move to `Docs/Plans/Archived/` with `status: complete` when done.

## Disposition

Completed work remains in the repository. The deferred frozen-mystery, artwork,
codegen, build-avoidance, feedback, and measured damage-pipeline candidates were
triaged into `SimplificationFollowup.md`; the overlapping remainder is
superseded and ready for archival.
