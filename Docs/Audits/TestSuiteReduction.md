# Test Suite Reduction Audit

Date: 2026-07-12

## Result

The checkout started with approximately 940 authored test declarations (913 Swift Testing declarations plus 27 XCTest methods). The current inventory contains 761 declarations: 736 Swift Testing declarations and 25 XCTest methods, a 19.0% declaration reduction.

This change establishes the ownership and tier boundaries needed for further reduction while preserving the unique battle, persistence, balance, app-transition, and player-flow owners. It does not claim the plan's 600–625 target has been reached; the remaining candidates need another review pass because the current worktree contains substantial unrelated edits and generated-content churn.

The largest verified runtime win is UI tier de-duplication: FullUI.xctestplan explicitly selects exhaustive UI classes and no longer automatically includes smoke classes. The long Play hierarchy journey remains covered, but is now exhaustive-tier-only. Smoke screen-load overlap was removed or merged where a stronger flow owns the same launch.

## Disposition vocabulary

- **keep** — unique semantic owner or required boundary/invariant coverage.
- **merge** — folded into a semantic matrix or cross-catalog invariant; the replacement owns the assertions.
- **remove** — duplicate, brittle implementation detail, or weaker example with stronger coverage elsewhere.
- **tier-only** — retained, but assigned to one execution tier to prevent overlap.

## Ownership decisions implemented

| Area | Change | Replacement / owner |
|---|---|---|
| UI tiers | Full UI explicitly selects exhaustive classes and excludes smoke classes. | FullUI.xctestplan; smoke remains the critical canary. |
| UI smoke | Removed redundant collection/homestead loads; retained the locked-state flow as its own smoke owner after the combined launch proved scroll-order-sensitive; moved long Play hierarchy journey to exhaustive UI. | Stronger collection, Homestead detail, and Play flow coverage. |
| Battle DoT | Merged handler tick examples into semantic decay rules; removed repeated ability-specific BattleState examples and duplicate DoT/control-meter pipeline cases. | DoTMechanicsTests, EffectTickEngineTests, ControlMeterEngineTests, integration tests, and deterministic simulations. |
| Battle runtime | Collapsed health/mana bounds and roster targeting examples into semantic contracts. | CombatantRuntimeTests, BattleRosterTests. |
| Content/art | Replaced exact count/snapshot checks and repeated art loops with invariants and cross-domain checks. | Catalog invariant, art manifest, registry-parity, and generated-content tests. |
| Design system | Removed material/shadow implementation-detail assertions; merged motion/experience/path semantic checks. | Public semantic tokens, contrast, experience math, motion contracts, keyword styles, and path-rail geometry. |
| Persistence | Reduced shell session cases to round-trip, migration, and stale-field ownership; removed redundant roster/stage/homestead cases. | Persistence store, sanitizer, journey, reward, and state-rule owners. |
| App orchestration | Removed duplicate map-scroll/reset/launch assertions and consolidated shell/audio/app-battle semantics. | App transition and persistence write-through owners. |
| Auto-end timing | Injected BattleSession auto-end delay with the production default retained; test support uses a near-zero delay and polling. | BattleSession production default plus BattleSessionSimulationTests. |

## Verification snapshot

- Style, Swift Testing migration, and module-boundary checks passed.
- TrinketCore, TrinketContent, TrinketDesignSystem, BattleEngine, and TrinketPersistence package suites passed.
- App unit suite passed with 201 tests.
- Homestead smoke passed with 3 tests; the full smoke tier passed with 8 tests after updating the renamed `Research` category lookup to `Arcana`.
- The exhaustive UI tier completed 17 tests: 13 passed and 4 failed in existing PlayMap/TabNavigation flows (`Battle Party Hero Control`, the duplicate `Weapon item slot` match, and `Stage 1-1 Enemy Art`). These are recorded as UI test failures, not simulator SIGKILLs, and were not removed or hidden by this reduction.
- Timing evidence is recorded by `./Scripts/test-timing.sh report`; UI launch cost remains the dominant runtime hotspot.

## Declaration inventory

Every declaration currently present in the checkout is listed below. The disposition is the disposition for the retained declaration after this change; merged and removed declarations are summarized in the ownership table above and in the source diff.

| Declaration | Location | Disposition |
|---|---|---|
| TrinketUITests/Play/PlayMapUITests.swift:14 |     func testStageEnemyArtInspection() { | keep |
| TrinketUITests/Play/PlayMapUITests.swift:29 |     func testChapterOverviewShowsFiveStagesWithoutRewardsCompactPartyAndBoss() { | keep |
| TrinketUITests/Play/PlayMapUITests.swift:45 |     func testChapterAdvanceContinuesFromClearedChapter() { | keep |
| TrinketUITests/Play/PlayMapUITests.swift:64 |     func testNonBattleStubStageCanComplete() { | keep |
| TrinketUITests/Play/PlayMapUITests.swift:74 |     func testBattleUsesCompactPartyPicker() { | keep |
| TrinketUITests/Play/PlayMapUITests.swift:106 |     func testAspectBattleUsesInlinePartyPicker() { | keep |
| TrinketUITests/Play/PlayMapUITests.swift:132 |     func testLabyrinthBattleUsesInlinePartyPicker() { | keep |
| TrinketUITests/Play/PlayMapUITests.swift:147 |     func testFinalStageOfChapterOffersAdvanceInsteadOfAutoJump() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ArtCatalogIntegrationTests.swift:11 |     @Test func catalogAndContentArtReferencesResolveAcrossAllDomains() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ArtCatalogIntegrationTests.swift:92 |     @Test func backgroundFocalPointsAreNormalized() { | keep |
| TrinketUITests/Play/PlayModeNavigationUITests.swift:15 |     func testCampaignAndExploreSubModesNavigateWithExpectedBackHierarchy() { | tier-only |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/ThemePaletteTests.swift:6 |     @Test func themePaletteUsesBundledSemanticColors() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/ThemePaletteTests.swift:28 |     @Test func semanticForegroundsMeetContrastInDarkEnvironment() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/EnemyCatalogTests.swift:14 |     @Test(arguments: GameContent.enemies) | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/EnemyCatalogTests.swift:37 |     @Test func specialEnemyLoadoutsMatchTheirArchetypes() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/EnemyCatalogTests.swift:51 |     @Test func idsAreUniqueAcrossCombatants() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/EnemyCatalogTests.swift:59 |     @Test func averagePlayerBaseHealthExceedsNormalEnemyBaseHealth() throws { | keep |
| TrinketUITests/Play/MysteryRecruitUITests.swift:5 |     func testRecruitMysteryUnlockFlow() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/CombatantCatalogTests.swift:5 |     @Test func homesteadNodeIDsAreUnique() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/CombatantCatalogTests.swift:10 |     @Test func homesteadPrerequisitesReferenceKnownNodes() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/CombatantCatalogTests.swift:22 |     @Test func playerCombatantsHaveCompleteAbilityChoicesAndLoadouts() throws { | keep |
| TrinketTests/Audio/CombatSFXMapperTests.swift:9 |     @Test func semanticFeedbackMappingsCoverTypedFallbackAndSilentCases() { | keep |
| TrinketTests/Audio/CombatSFXMapperTests.swift:91 |     @Test func catalogContainsExpectedIDs() { | keep |
| TrinketTests/Audio/CombatSFXMapperTests.swift:109 |     @Test func uniqueClipIDsDedupesIdenticalClips() { | keep |
| TrinketTests/Audio/CombatSFXMapperTests.swift:119 |     @Test func uniqueClipIDsPrefersTypedHitOverGenericPhysicalHit() { | keep |
| TrinketTests/Audio/CombatSFXMapperTests.swift:127 |     @Test func uniqueClipIDsKeepsPoisonHitAlongsideBurn() { | keep |
| TrinketTests/Audio/CombatSFXMapperTests.swift:137 |     @Test func uniqueClipIDsKeepsOneBurnAcrossMultipleTargets() { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/VerticalPathRailTests.swift:6 |     @Test func pathConnectorStyleHomesteadAccentUsesPalette() { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/VerticalPathRailTests.swift:13 |     @Test func pathNodeMetricsExposeSharedGeometryAndStrokeWeights() { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectPresentationTests.swift:5 |     @Test func activePhraseFormatsControlMeterBuildUp() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectPresentationTests.swift:15 |     @Test func activePhraseFormatsTriggeredControlAsStatusAlias() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectPresentationTests.swift:25 |     @Test func activePhraseFormatsDeathsDoor() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectPresentationTests.swift:35 |     @Test func applyPhraseFormatsBlockWithAmount() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectPresentationTests.swift:42 |     @Test func applyPhraseFormatsDamageKeywordOverride() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyContentTests.swift:10 |     @Test func eachRewardItemTemplateExists() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyContentTests.swift:21 |     @Test func everyChapterHasFiveSequentialStages() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyContentTests.swift:36 |     @Test func chapterEncounterCadenceMatchesTheCurrentJourney() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyContentTests.swift:61 |     @Test func placeholderEncountersMatchTheApprovedChapterLineup() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyContentTests.swift:78 |     @Test func nextStageReturnsNilAfterFinalStage() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyContentTests.swift:85 |     @Test func nextStageCrossesIntoFollowingChapter() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:6 |     @Test func catalogIDsAreUnique() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:11 |     @Test func unknownAbilityLookupReturnsNil() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:15 |     @Test func staticReexportsMatchCatalog() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:21 |     @Test func doTPairingMatchesDamageComponents() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:65 |     @Test func bloodthornUsesDamageComponents() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:72 |     @Test func catalogPassesValidation() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:77 |     @Test func abilityBuilderMatchesDirectHitPattern() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:90 |     @Test func directHitBuilderAddsPairedDoT() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:107 |     @Test func buffOnlyBuilderProducesGeneratedDescription() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:117 |     @Test func multiDamageBuilderFormatsSummary() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:138 |     @Test func representativeAbilitySummariesPreserveProductContracts() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:155 |     @Test func descriptionOverridesAreAllowlisted() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift:164 |     @Test(arguments: AbilityCatalog.all) | keep |
| TrinketTests/Audio/MusicPlayerRoutingTests.swift:7 |     @Test func menuRoutePlaysMenuTrackWhenNoEncounterIsActive() throws { | keep |
| TrinketTests/Audio/MusicPlayerRoutingTests.swift:21 |     @Test func normalBattlePreviewPlaysBattleTrack() throws { | keep |
| TrinketTests/Audio/MusicPlayerRoutingTests.swift:37 |     @Test func bossBattlePreviewPlaysBossTrack() throws { | keep |
| TrinketTests/Audio/MusicPlayerRoutingTests.swift:52 |     @Test func activeBattleTakesPriorityOverPreview() throws { | keep |
| TrinketTests/Audio/MusicPlayerRoutingTests.swift:74 |     @Test func leavingPlayReturnsToMenuEvenWithActiveBattle() throws { | keep |
| TrinketTests/Audio/MusicPlayerRoutingTests.swift:96 |     @Test func inactiveSceneSilencesAndPreservesPosition() { | keep |
| TrinketTests/Audio/MusicPlayerRoutingTests.swift:108 |     @Test func mutedMusicSilencesAndPreservesPosition() { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AbilityEffectIntegrationTests.swift:8 |     @Test func blackjackGrantsGoldAlongsideStunDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AbilityEffectIntegrationTests.swift:25 |     @Test func poisonEffectAppliesThroughTargetedEffects() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AbilityEffectIntegrationTests.swift:44 |     @Test func bloodthornDealsComponentDamageAndAppliesDoTs() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AbilityEffectIntegrationTests.swift:85 |     @Test func prayerCleanseRandomRemovesOneDebuffAndHeals() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AbilityEffectIntegrationTests.swift:117 |     @Test func damageKeywordOverrideRewritesOutgoingDamageToHolyWithBonus() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AbilityEffectIntegrationTests.swift:154 |     @Test func avatarOfJusticeAppliesManifestDefensiveEffects() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/TrinketMotionTests.swift:5 |     @Test func battleMotionTimingTokensStayWithinContracts() { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/TrinketMotionTests.swift:18 |     @Test func everyCombatFeedbackClassHasPositiveLifetimeRecipe() { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/TrinketMotionTests.swift:29 |     @Test func chipMotionRecipesStayWithinSemanticContracts() { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/TrinketMotionTests.swift:44 |     @Test func cardReactionsCoverAllKinds() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:8 |     @Test func sanitizeInventoryRemovesDuplicateItemIDs() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:33 |     @Test func sanitizeHomesteadClampsMaterialBalances() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:53 |     @Test func sanitizeJourneyClampsInvalidStageAndChapterIDs() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:68 |     @Test func sanitizeJourneyAlignsActiveChapterWithActiveStage() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:80 |     @Test func sanitizeJourneyPreservesClearedChapterAwaitingAdvance() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:94 |     @Test func sanitizeJourneyMarksClaimedStagesAsCompleted() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:104 |     @Test func sanitizeRosterFiltersInvalidUnlockIDs() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:122 |     @Test func sanitizeRosterClampsGoldBalance() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:131 |     @Test func sanitizeRosterFallsBackToStartersWhenUnlocksEmpty() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:151 |     @Test func sanitizeRosterStripsUnknownCombatantAbilityLoadouts() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:176 |     @Test func sanitizeRosterResolvesInvalidAbilityIDs() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:204 |     @Test func sanitizeRosterPrunesMissingEquipmentItems() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:237 |     @Test func sanitizeRosterStripsWeaponSlotFromCompanions() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveSanitizerTests.swift:283 |     @Test func sanitizeFullPipelineCombinesInventoryAndRoster() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/GameContentTraitCatalogTests.swift:5 |     @Test func everyHeroAndCompanionReferencesKnownTrait() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/GameContentTraitCatalogTests.swift:21 |     @Test func everyCombatantHasExactlyOneTraitMapping() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/GameContentTraitCatalogTests.swift:27 |     @Test func everyEnemyHasPositiveAndNegativeTraits() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/GameContentTraitCatalogTests.swift:39 |     @Test func traitDescriptionsAreNonEmpty() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/GameContentTraitCatalogTests.swift:46 |     @Test func traitIDsAreUnique() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectModelTests.swift:5 |     @Test func representativeEffectSummariesAndProperties() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectModelTests.swift:14 |     @Test func activeEffectTracksRemainingTicks() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectModelTests.swift:23 |     @Test func effectKindMatchesCase() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectModelTests.swift:52 |     @Test func effectKindIsUniquePerCase() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectModelTests.swift:56 |     @Test func isRemovableDebuffMatchesPriorDefinition() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectModelTests.swift:74 |     @Test func isRemovableBuffMatchesDefinition() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/EffectModelTests.swift:83 |     @Test func isTickableMatchesPriorDefinition() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift:50 |     @Test func infectedAppliesPoisonWhenBleedIsApplied() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift:64 |     @Test func relentlessRefreshesBleedInsteadOfAddingAStack() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift:83 |     @Test func frostburnDealsFreezeDamageEveryThirdBurnTick() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift:105 |     @Test func cascadingGrantsArmorWhenBlockBreaks() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift:136 |     @Test func symbiosisSharesHeroHealingWithCompanion() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift:164 |     @Test func secondWindHealsOnlyOnceWhenHealthFallsLow() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift:195 |     @Test func deathsDoorProcsBeforeSecondWindOnLethalHit() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/AffixReactionBattleTests.swift:222 |     @Test func shatterAddsFreezeDamageWhileEnemyIsFrozen() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/CombatantEquipmentTests.swift:6 |     @Test func companionEquipmentSlotsUseTwoTrinketsAndArmor() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/CombatantEquipmentTests.swift:12 |     @Test func heroEquipmentSlotsKeepWeaponArmorTrinket() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/CombatantEquipmentTests.swift:18 |     @Test func secondaryTrinketSlotAcceptsTrinketItems() throws { | keep |
| TrinketTests/Journey/JourneyMapPresentationTests.swift:11 |     @Test func activeJourneyScrollsToActiveStage() { | keep |
| TrinketTests/Journey/JourneyMapPresentationTests.swift:36 |     @Test func activeStageAppearsInRows() { | keep |
| TrinketTests/Journey/JourneyMapPresentationTests.swift:60 |     @Test func completedStagesAreExcludedFromRows() { | keep |
| TrinketTests/Journey/JourneyMapPresentationTests.swift:78 |     @Test func justCompletedStageIsExcludedFromRows() { | keep |
| TrinketTests/Journey/JourneyMapPresentationTests.swift:95 |     @Test func rowsEndWithChapterGate() { | keep |
| TrinketTests/Journey/JourneyMapPresentationTests.swift:113 |     @Test func completedChapterScrollsToLastStageWhileAwaitingAdvance() { | keep |
| TrinketTests/Journey/JourneyMapPresentationTests.swift:140 |     @Test func scrollTargetStaysOnClearedChapterUntilAdvance() { | keep |
| TrinketTests/Journey/JourneyMapPresentationTests.swift:162 |     @Test func gateChapterUsesPlaceholderWhenNextChapterMissing() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/VisualFoundationTests.swift:6 |     @Test func backgroundModeDisplayNamesAreNonEmpty() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/VisualFoundationTests.swift:13 |     @Test func typographyRolesProvideFonts() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/VisualFoundationTests.swift:23 |     @Test func homesteadPaletteUsesDarkChrome() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ShopOfferGeneratorTests.swift:6 |     @Test func generatesRequestedOfferCount() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ShopOfferGeneratorTests.swift:16 |     @Test func pricesFollowBasicAndAstralRules() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ShopOfferGeneratorTests.swift:36 |     @Test func rarityMixIsMostlyBasicAcrossManyRolls() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ShopOfferGeneratorTests.swift:61 |     @Test func sameSeedProducesIdenticalOffers() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ShopOfferGeneratorTests.swift:71 |     @Test func emptyBaseTypesYieldNoOffers() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ShopOfferGeneratorTests.swift:81 |     @Test func offerIDsAreUniqueWithinAShelf() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ShopOfferGeneratorTests.swift:91 |     @Test func shopOfferItemsResolveArtByTemplateID() { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/MarkedConsumeTests.swift:8 |     @Test func markedConsumedWhenFullyShielded() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/StatGrowthTests.swift:5 |     @Test func playerGrowthCoversBaselineHealthAndArchetypes() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/StatGrowthTests.swift:12 |     @Test func mageGrowthAddsIntellectAndMana() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/StatGrowthTests.swift:18 |     @Test func nonBossEnemyGrowthMatchesPlayerGrowth() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/StatGrowthTests.swift:29 |     @Test func bossGrowthSpikesPrimaryStat() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/StatGrowthTests.swift:42 |     @Test func enemyGearCompensationScalesSmoothlyWithLevel() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/StatGrowthTests.swift:59 |     @Test func applyMergesGrowthIntoStats() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:15 |     @Test func playerSavePersistsJourneyRosterInventoryAndHomestead() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:35 |     @Test func swiftDataGraphStoresIndependentRecords() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:62 |     @Test func resetGameplayProgressRestoresFreshStart() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:78 |     @Test func applyTestSeedMatchesDeterministicUITestBaseline() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:87 |     @Test func unlockAllContentUnlocksRosterAndClearsChapterOne() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:123 |     @Test func equipmentLoadoutDropsMissingInventoryItemsOnLoad() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:138 |     @Test func rosterCacheReturnsConsistentHydratedState() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:159 |     @Test func localMutationUpdatesModifiedAt() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:167 |     @Test func sanitizerDropsRemovedStagesAndUsesCatalogOrderForLastCompletedStage() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:180 |     @Test func validateRejectsNegativeProgressionXP() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:194 |     @Test func validateRejectsInvalidSchemaVersion() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:207 |     @Test func performBatchMutationPreservesStateWhenValidationFails() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerSaveStoreTests.swift:224 |     @Test func performBatchMutationRollsBackInMemoryStateWhenSaveFails() throws { | keep |
| TrinketTests/Journey/StageMapPresentationTests.swift:7 |     @Test func chapterGateIDUsesChapterIdentifier() { | keep |
| TrinketTests/Journey/StageMapPresentationTests.swift:13 |     @Test func placeholderGateIDUsesChapterNumber() { | keep |
| TrinketTests/Journey/StageMapPresentationTests.swift:17 |     @Test func chapterJourneyRowIDMatchesStageOrGate() throws { | keep |
| TrinketTests/Journey/StageMapPresentationTests.swift:31 |     @Test func stageMapLabelFormatsChapterAndStageNumber() throws { | keep |
| TrinketTests/Journey/StageMapPresentationTests.swift:38 |     @Test func chapterRowsKeepAllFiveStagesAndStopProgressAtTheActiveNode() { | keep |
| TrinketTests/Journey/StageMapPresentationTests.swift:59 |     @Test func bossAndRecruitmentPresentationAreDerivedFromLiveContent() { | keep |
| TrinketTests/Journey/StageMapPresentationTests.swift:68 |     @Test func clearedChapterShowsEveryReadOnlyRowUntilAdvance() { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/PaletteTests.swift:7 |     @Test func bundledEncounterAndKeywordColorsResolve() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/PaletteTests.swift:14 |     @Test func healthAndOverlayTokensResolveFromPalette() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/PaletteTests.swift:24 |     @Test func homesteadResourceAndTintColorsResolve() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/PaletteTests.swift:33 |     @Test func publicSemanticPaletteHasValidColors() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemAffixCatalogTests.swift:5 |     @Test func affixIDsAreUnique() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemAffixCatalogTests.swift:10 |     @Test func eachAffixHasPositiveWeightAndKeywords() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemAffixCatalogTests.swift:17 |     @Test func eachAffixDefinesBasicAndAstralPowers() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemAffixCatalogTests.swift:32 |     @Test func eachItemBaseTypeHasEligibleAffixPool() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemAffixCatalogTests.swift:42 |     @Test func revisedAffixesUseConsistentLeechAndHybridWording() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemAffixCatalogTests.swift:64 |     @Test func newArchetypeAndUtilityAffixesArePresent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTMechanicsTests.swift:52 |     @Test func burnFourDealsFourThenTwoThenOne() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTMechanicsTests.swift:72 |     @Test func burnStacksMergeAndDecayTogether() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTMechanicsTests.swift:91 |     @Test func poisonEightDecaysToZero() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTMechanicsTests.swift:109 |     @Test func poisonAppliesInitialDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTMechanicsTests.swift:120 |     @Test func bleedFourInstancesDealSixteenTotal() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTMechanicsTests.swift:136 |     @Test func bleedInstancesTrackIndependently() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTMechanicsTests.swift:151 |     @Test func burnRespectsBlockAndArmor() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTMechanicsTests.swift:174 |     @Test func cleanseRemovesMergedPoisonStack() throws { | keep |
| TrinketUITests/Collection/TabNavigationUITests.swift:4 |     func testHeroDetailEquipmentAndAbilities() { | keep |
| TrinketUITests/Collection/TabNavigationUITests.swift:43 |     func testFreshStartItemSlotsRenderLockedUntilSlotItemExists() { | keep |
| TrinketUITests/Collection/TabNavigationUITests.swift:64 |     func testTabBarRoundTrip() { | keep |
| TrinketUITests/Collection/TabNavigationUITests.swift:79 |     func testInventoryGridLayout() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/EncounterLevelResolverTests.swift:5 |     @Test func journeyEnemyLevelSpansFiveLevelsPerChapter() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/EncounterLevelResolverTests.swift:21 |     @Test func nonBattleStagesReturnChapterBaseLevel() throws { | keep |
| TrinketTests/State/OptionsUltimateSkipPolicyTests.swift:7 |     @Test func oncePerBattleAutoSkipsAfterActorPresented() throws { | keep |
| TrinketTests/State/OptionsUltimateSkipPolicyTests.swift:33 |     @Test func migratesLegacyAfterFirstViewToOncePerBattle() throws { | keep |
| TrinketTests/State/OptionsUltimateSkipPolicyTests.swift:40 |     @Test func neverPolicyBlocksSkip() throws { | keep |
| TrinketTests/State/OptionsUltimateSkipPolicyTests.swift:53 |     @Test func alwaysPolicyAllowsSkipAndNeverAutoSkips() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsModelTests.swift:6 |     @Test func defaultStatsEqualZero() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsModelTests.swift:15 |     @Test func primaryStatsCodable() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/ExperienceBarTests.swift:6 |     @Test func experienceSegmentsCoverNoChangeAndPartialProgress() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/ExperienceBarTests.swift:24 |     @Test func singleLevelUpProducesTwoSegments() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/ExperienceBarTests.swift:44 |     @Test func multiLevelUpProducesThreeSegments() throws { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/ExperienceBarTests.swift:74 |     @Test func levelChainsMatchAddingExperience() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ItemModifierBattleTests.swift:7 |     @Test func equippedPhysicalDamageAffixIncreasesDirectDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ItemModifierBattleTests.swift:39 |     @Test func equippedMaximumHealthAffixIncreasesStartingHealth() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ItemModifierBattleTests.swift:70 |     @Test func equippedMightyAffixIncreasesStrengthBasedDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ItemModifierBattleTests.swift:107 |     @Test func equippedSerratedAffixIncreasesBleedDamage() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/GameContentCatalogInvariantTests.swift:5 |     @Test func itemBaseIDsAreUnique() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/GameContentCatalogInvariantTests.swift:10 |     @Test(arguments: GameContent.chapters.flatMap(\.stages)) | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/GameContentCatalogInvariantTests.swift:21 |     @Test(arguments: GameContent.chapters.flatMap(\.stages)) | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/GameContentCatalogInvariantTests.swift:34 |     @Test(arguments: GameContent.chapters.flatMap(\.stages)) | keep |
| TrinketTests/State/OptionsStoreTests.swift:12 |     @Test func defaultsWhenNoStoredValues() { | keep |
| TrinketTests/State/OptionsStoreTests.swift:25 |     @Test func loadsPreviouslyStoredValues() { | keep |
| TrinketTests/State/OptionsStoreTests.swift:42 |     @Test func musicVolumePersistsOnChange() { | keep |
| TrinketTests/State/OptionsStoreTests.swift:50 |     @Test func effectsVolumePersistsOnChange() { | keep |
| TrinketTests/State/OptionsStoreTests.swift:58 |     @Test func hapticsEnabledPersistsOnChange() { | keep |
| TrinketTests/State/OptionsStoreTests.swift:66 |     @Test func appStorageKeysMatchPublicConstants() { | keep |
| Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/KeywordVisualStyleTests.swift:7 |     @Test func allKeywordsHaveVisualStyle() throws { | keep |
| TrinketTests/App/AppEnvironmentTests.swift:7 |     @Test(arguments: AppTab.allCases) | keep |
| TrinketTests/App/AppEnvironmentTests.swift:13 |     @Test(arguments: ["heroes", "companions", "inventory", "search", "Heroes", "COMPANIONS", "SEARCH"]) | keep |
| TrinketTests/App/AppEnvironmentTests.swift:19 |     @Test func invalidSelectedTabReturnsNil() { | keep |
| TrinketTests/App/AppEnvironmentTests.swift:24 |     @Test func launchScreenParsingCoversDetailsModesAndBoundaries() { | keep |
| TrinketTests/App/AppEnvironmentTests.swift:48 |     @Test func commandLineFlagsParseAsSemanticGroups() { | keep |
| TrinketTests/App/AppEnvironmentTests.swift:72 |     @Test func noFlagsYieldsDefaultEnvironment() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemGeneratorTests.swift:6 |     @Test func basicItemsRollOneOrTwoAffixes() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemGeneratorTests.swift:15 |     @Test func astralItemsRollThreeOrFourAffixes() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemGeneratorTests.swift:24 |     @Test func generatedItemsDoNotDuplicateAffixes() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemGeneratorTests.swift:38 |     @Test func generatedAffixesMatchSlotAndAnyKeywordAffinity() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemGeneratorTests.swift:56 |     @Test func everyBaseTypeHasEnoughEligibleAffixesForAstralMaximum() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemGeneratorTests.swift:67 |     @Test func seededGenerationIsReproducible() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemGeneratorTests.swift:88 |     @Test func astralAffixesResolveStrongerThanBasicAffixes() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemGeneratorTests.swift:99 |     @Test func guaranteedAffixIDsAreAlwaysIncluded() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ItemGeneratorTests.swift:115 |     @Test func mysteryItemRarityRollsBasicEightyPercent() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsRulesTests.swift:5 |     @Test func statBonusForDamageUsesCorrectStat() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsRulesTests.swift:19 |     @Test func dodgeChanceCapsAtSeventyFivePercent() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsRulesTests.swift:26 |     @Test func armorEffectivenessBonusMatchesFormula() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsRulesTests.swift:33 |     @Test func controlMeterThresholdScalesWithAgility() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsRulesTests.swift:38 |     @Test func criticalChanceUsesBaseAndStatScaling() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsRulesTests.swift:46 |     @Test func controlMeterThresholdUsesCeilOfTwentyPercentMaxHealth() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsRulesTests.swift:61 |     @Test func zeroStatsProduceBaselineBonuses() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsRulesTests.swift:68 |     @Test func negativeStatInputsTruncateTowardZeroForDamageBonus() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleMechanicsTests.swift:42 |     @Test func markedBonusAddsDamageAndConsumesMark() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleMechanicsTests.swift:68 |     @Test func enemyAbilityCadenceSelectsSkillOnThirdTurn() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleMechanicsTests.swift:87 |     @Test func predatorsHasteIsNoOp() throws { | keep |
| TrinketUITests/Battle/BattleFlowUITests.swift:5 |     func testMidBattleCombatantDetailAndHandChrome() { | keep |
| TrinketUITests/Battle/BattleFlowUITests.swift:42 |     func testBattleVictorySummaryAndPostVictoryMenu() { | keep |
| TrinketUITests/Battle/BattleFlowUITests.swift:59 |     func testRetreatRestoresPlayNavigation() { | keep |
| TrinketTests/State/AppStateSessionPersistenceTests.swift:17 |     @Test func defaultsWhenNoStoredValues() throws { | keep |
| TrinketTests/State/AppStateSessionPersistenceTests.swift:24 |     @Test func migratesPreviouslyStoredTabFromLegacyUserDefaultsButLandsOnPlay() throws { | keep |
| TrinketTests/State/AppStateSessionPersistenceTests.swift:33 |     @Test func discardsLegacyBattleStageIDFromUserDefaults() throws { | keep |
| TrinketTests/State/AppStateSessionPersistenceTests.swift:42 |     @Test func migratesPreviouslyStoredMapScrollStageIDFromLegacyUserDefaults() throws { | keep |
| TrinketTests/State/AppStateSessionPersistenceTests.swift:50 |     @Test func selectedTabPersistsOnChangeButRelaunchLandsOnPlay() throws { | keep |
| TrinketTests/State/AppStateSessionPersistenceTests.swift:57 |     @Test func mapScrollStageIDPersistsOnChange() throws { | keep |
| TrinketTests/State/AppStateSessionPersistenceTests.swift:64 |     @Test func noteMapScrollFocusPersistsTargetAndPublishesFocus() throws { | keep |
| TrinketTests/State/AppStateSessionPersistenceTests.swift:74 |     @Test func noteMapScrollFocusIncrementsRevisionWhenTargetUnchanged() throws { | keep |
| TrinketUITests/Smoke/SmokePlayTests.swift:15 |     func testPlayScreenLoadsWithCampaignAndExploreChoices() { | keep |
| TrinketTests/App/AppStateTests.swift:15 |     @Test func defaultInitSelectsPlayTabWithFreshSave() throws { | keep |
| TrinketTests/App/AppStateTests.swift:25 |     @Test func launchTabOverridesDefaultTab() throws { | keep |
| TrinketTests/App/AppStateTests.swift:33 |     @Test func collectionDetailLaunchScreensMapToCollectionPresentations() throws { | keep |
| TrinketTests/App/AppStateTests.swift:76 |     @Test func battleLaunchScreensStartOnPlayWithExpectedState() throws { | keep |
| TrinketTests/App/AppStateTests.swift:86 |     @Test func battleVictoryLaunchScreenShowsVictoryChrome() throws { | keep |
| TrinketTests/App/AppStateTests.swift:98 |     @Test func shopLaunchScreenOpensMerchantShop() throws { | keep |
| TrinketTests/App/AppStateTests.swift:114 |     @Test func mysteryLaunchScreenOpensRecruitEncounter() throws { | keep |
| TrinketTests/App/AppStateTests.swift:128 |     @Test func seedTestProgressPopulatesInventory() throws { | keep |
| TrinketTests/App/AppStateTests.swift:138 |     @Test func optionsLaunchScreenDefaultsToOptionsTab() throws { | keep |
| TrinketTests/App/AppStateTests.swift:146 |     @Test func resetStateWipesPersistedSave() throws { | keep |
| TrinketTests/App/AppStateTests.swift:169 |     @Test func seedTestProgressAppliesDeterministicBaseline() throws { | keep |
| TrinketTests/App/AppStateTests.swift:178 |     @Test func completedStagesAdvanceJourneyAndMarkRewardsClaimed() throws { | keep |
| TrinketTests/App/AppStateTests.swift:187 |     @Test func unknownCompletedStageIDsAreIgnored() throws { | keep |
| TrinketTests/App/AppStateTests.swift:195 |     @Test func mapScrollTargetLaunchArgSetsSessionScrollFocus() throws { | keep |
| TrinketTests/App/AppStateTests.swift:204 |     @Test func completeStageUpdatesStoresAndMapScrollFocus() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/KeywordCoreTests.swift:5 |     @Test func allKeywordsAreCovered() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/KeywordCoreTests.swift:14 |     @Test(arguments: Keyword.allCases) | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/KeywordCoreTests.swift:19 |     @Test(arguments: Keyword.allCases) | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/KeywordCoreTests.swift:24 |     @Test(arguments: [Keyword.physical, .burn, .poison, .bleed, .holy, .nature, .freeze, .stun]) | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/KeywordCoreTests.swift:29 |     @Test(arguments: [Keyword.block, .armor, .dodge, .purge]) | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/KeywordCoreTests.swift:34 |     @Test(arguments: [Keyword.health, .leech, .deathsDoor]) | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/KeywordCoreTests.swift:39 |     @Test(arguments: [Keyword.gold, .mana]) | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/KeywordCoreTests.swift:44 |     @Test func statusAliases() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/KeywordCoreTests.swift:52 |     @Test func categoryAllCases() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityLoadoutTests.swift:7 |     @Test func selectingReplacesAbilityInMatchingTier() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityLoadoutTests.swift:17 |     @Test func unlockedFiltersTiersByProgressionLevel() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityLoadoutTests.swift:28 |     @Test func unlockedRestoresUltimateAtLevelSix() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityLoadoutTests.swift:37 |     @Test func abilityChoicesFallsBackWhenSelectedAbilityMissingFromPool() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/TraitBattleTests.swift:60 |     @Test func packLeaderIncreasesCompanionDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/TraitBattleTests.swift:84 |     @Test func purifyingWisdomHealsAfterCleanse() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/TraitBattleTests.swift:117 |     @Test func faeFortuneHealsWhenGainingGold() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/TraitBattleTests.swift:149 |     @Test func loyalComfortHealsHeroWhenCompanionRestoresHealth() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/ExperienceScalingTests.swift:5 |     @Test func adjustedAwardCoversLevelBoundaries() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/ExperienceScalingTests.swift:20 |     @Test func underlevelGapScalesSmoothly() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/ExperienceScalingTests.swift:29 |     @Test func baseBattleAwardTargetsEarlyMidAndLateProgression() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/ExperienceScalingTests.swift:43 |     @Test func battleAwardAppliesLevelDeltaMultiplier() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/ExperienceScalingTests.swift:50 |     @Test func catchUpMultiplierCoversBaselineGrowthAndCaps() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/ExperienceScalingTests.swift:71 |     @Test func battleAwardWithCatchUpReturnsZeroWhenBaseAwardIsZero() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/ExperienceScalingTests.swift:77 |     @Test func battleAwardWithCatchUpAppliesCatchUpMultiplier() throws { | keep |
| TrinketTests/Homestead/HomesteadPresentationTests.swift:8 |     @Test func lockedProjectsPreviewTierOneAndKeepTierPathLocked() throws { | keep |
| TrinketTests/Homestead/HomesteadPresentationTests.swift:19 |     @Test func unbuiltProjectsDistinguishAffordableBuilds() throws { | keep |
| TrinketTests/Homestead/HomesteadPresentationTests.swift:32 |     @Test func builtProjectsExposeOnlyTheirCurrentEffect() throws { | keep |
| TrinketTests/Homestead/HomesteadPresentationTests.swift:44 |     @Test func upgradeReadyAppearsOnlyWhenTheNextTierIsAffordable() throws { | keep |
| TrinketTests/Homestead/HomesteadPresentationTests.swift:67 |     @Test func completedProjectsExposeFinalEffectAndCompleteFooter() throws { | keep |
| TrinketTests/Homestead/HomesteadPresentationTests.swift:79 |     @Test func tierPathMapsCurrentTiersZeroThroughThree() throws { | keep |
| TrinketTests/Homestead/HomesteadPresentationTests.swift:111 |     @Test func tierPathConnectorsMatchStageSelectProgressFrontier() throws { | keep |
| TrinketUITests/Smoke/SmokeCollectionTests.swift:4 |     func testFreshStartCollectionHidesInventorySection() { | keep |
| TrinketTests/App/AppStateAspectsTests.swift:15 |     @Test func startAspectBattleIsAvailableFromFreshState() throws { | keep |
| TrinketTests/App/AppStateAspectsTests.swift:24 |     @Test func startAspectBattleRequiresAttunement() throws { | keep |
| TrinketTests/App/AppStateAspectsTests.swift:43 |     @Test func startAspectBattleSucceedsWhenAttuned() throws { | keep |
| TrinketTests/App/AppStateAspectsTests.swift:56 |     @Test func startAspectBattleRejectsLockedFloor() throws { | keep |
| TrinketTests/App/AppStateAspectsTests.swift:65 |     @Test func startAspectBattleRejectsClearedFloor() throws { | keep |
| TrinketTests/App/AppStateAspectsTests.swift:76 |     @Test func completeAspectFloorAdvancesProgress() throws { | keep |
| TrinketTests/App/AppStateAspectsTests.swift:91 |     @Test func endAspectBattleClearsLiveBattle() throws { | keep |
| TrinketTests/App/AppStateAspectsTests.swift:101 |     @Test func startAspectBattlePreviewsFloorRewardItem() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/CombatantProgressionTests.swift:5 |     @Test func requiredXPFollowsQuadraticCurve() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/CombatantProgressionTests.swift:14 |     @Test func addingExperienceHandlesSingleAndMultipleLevelUps() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/CombatantProgressionTests.swift:26 |     @Test func addingNonPositiveExperienceIsNoOp() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/CombatantProgressionTests.swift:32 |     @Test func progressFractionClampsAndHandlesZeroRequired() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/CombatantProgressionTests.swift:46 |     @Test func unlocksRespectsAbilityTierLevels() throws { | keep |
| Packages/TrinketCore/Tests/TrinketCoreTests/CombatantProgressionTests.swift:56 |     @Test func atLevelBuildsEmptyProgressTowardNextLevel() throws { | keep |
| TrinketTests/Content/GameContentEncounterArtTests.swift:6 |     @Test func mappedEventStagesResolveEncounterArt() throws { | keep |
| TrinketTests/Content/GameContentEncounterArtTests.swift:15 |     @Test func recruitMysteryStageUsesCombatantPortraitArt() throws { | keep |
| TrinketTests/Content/GameContentEncounterArtTests.swift:27 |     @Test func unmappedBattleStageUsesEnemyArt() throws { | keep |
| TrinketTests/Content/GameContentEncounterArtTests.swift:36 |     @Test func shopStageUsesMerchantFallbackTitle() { | keep |
| TrinketUITests/Smoke/SmokeHeroDetailTests.swift:4 |     func testHeroDetailOverscrollHeaderPreservation() { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:16 |     @Test func completeActiveBattleWithStageCompletesJourneyAndEndsBattle() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:31 |     @Test func completeActiveBattleIsIdempotentWhenContinueTappedTwice() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:46 |     @Test func completeActiveBattleWithoutStageGrantsGoldOnly() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:67 |     @Test func completeActiveBattleKeepsBattleOpenWhenPersistFails() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:84 |     @Test func unlockAllContentUnlocksRosterAndClearsBattle() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:103 |     @Test func legacyBattleResumeKeysDoNotRestoreBattle() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:119 |     @Test func shouldRestoreMapScrollIgnoresCompletedStage() { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:127 |     @Test func startBattleSetsInMemoryJourneyOrigin() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:136 |     @Test func endBattleReturningToOriginFromJourneyQueuesCampaignDeepLink() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:149 |     @Test func endBattleReturningToOriginFromAspectQueuesClimbDeepLink() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:164 |     @Test func endBattleReturningToOriginFromLabyrinthQueuesMapDeepLink() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:178 |     @Test func completeActiveBattleQueuesAspectReturnDestination() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:190 |     @Test func presentCombatLogShowsLogWithoutChangingTabs() throws { | keep |
| TrinketTests/App/AppStatePlayFlowTests.swift:203 |     @Test func playLaunchDestinationMapsResumeTokens() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:9 |     @Test func ensureMapCreatesReachableNodes() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:17 |     @Test func markClearedExpandsPastGate() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:44 |     @Test func sanitizeDropsUnknownBiomeAndModifierIDs() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:56 |     @Test @MainActor func labyrinthPersistsThroughStore() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:73 |     @Test func completionGrantsGoldAndClearsNode() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:88 |     @Test func nonCombatCompletionDoesNotGrantBattleExperience() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:121 |     @Test func combatCompletionGrantsBattleExperience() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:143 |     @Test func recordDefeatIncrementsFailCountWithoutClearing() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:152 |     @Test func sanitizeCollapsesLegacyEventNodesToMystery() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/LabyrinthProgressTests.swift:173 |     @Test func forgeAtAltarSpendsGoldAndClearsCraftNode() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:8 |     @Test func biomesAreAuthoredWithResolvableEnemies() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:19 |     @Test func modifiersHavePlayerFacingTitles() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:27 |     @Test func generatorIsDeterministicForSeed() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:37 |     @Test func initialMapHasReachableEntryFromEntrance() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:47 |     @Test func expandBeyondGateAppendsNextBand() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:68 |     @Test func modifierEffectsCombineThreatAndBounty() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:76 |     @Test func generatorDoesNotEmitEventNodes() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:83 |     @Test func eventTypeCanonicalizesToMystery() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:89 |     @Test func legacyEliteNodeTypeDecodesAsBattle() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:100 |     @Test func threatModifiersAlwaysCarryBountyBump() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/LabyrinthCatalogTests.swift:130 |     @Test func clusterSizeStaysWithinPlanBounds() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyProgressTests.swift:14 |     @Test func completingStageUnlocksExactlyNextStage() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyProgressTests.swift:28 |     @Test func completedAndFutureStagesAreNotActive() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyProgressTests.swift:42 |     @Test func rewardsCanOnlyBeClaimedOncePerStage() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyProgressTests.swift:54 |     @Test func experienceAppliesToActiveParty() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyProgressTests.swift:68 |     @Test func itemRewardCreatesUniqueInstance() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyProgressTests.swift:82 |     @Test func chapterCompletionParksUntilAdvanceToNextChapter() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyProgressTests.swift:101 |     @Test func completeChapterMarksOnlyThatChapterDone() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyProgressTests.swift:119 |     @Test func completeAllStagesMarksEntireCampaignDone() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/JourneyProgressTests.swift:132 |     @Test func journeyPersistsProgress() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EnemyTraitBattleTests.swift:36 |     @Test func skeletonTakesExtraHolyDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EnemyTraitBattleTests.swift:54 |     @Test func goblinNimbleDodgeAndScrawnyVulnerability() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EnemyTraitBattleTests.swift:60 |     @Test func mimicAmbushAddsFirstStrikeDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EnemyTraitBattleTests.swift:77 |     @Test func livingArmorCannotBeHealed() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EnemyTraitBattleTests.swift:82 |     @Test func hemorrhageWithGravePowerDoesNotDoubleImmediateBleed() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ThemedGearGeneratorTests.swift:6 |     @Test func generatesFixedAffixCountPerSlot() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ThemedGearGeneratorTests.swift:24 |     @Test func keywordProfileIncludesAbilityKeywords() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ThemedGearGeneratorTests.swift:29 |     @Test func fixedAffixCountOverrideInItemGenerator() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/ThemedGearGeneratorTests.swift:45 |     @Test func requireBuildAlignmentRejectsMismatchedDamageAffixes() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:15 |     @Test func enterLabyrinthIsAvailableFromFreshState() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:23 |     @Test func enterLabyrinthReusesExistingMap() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:33 |     @Test func startLabyrinthBattleSetsConfiguration() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:44 |     @Test func completeLabyrinthNodeAdvancesMap() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:52 |     @Test func completeActiveBattleClearsLabyrinthNode() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:63 |     @Test func labyrinthShopFinishClearsNode() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:79 |     @Test func labyrinthShopDismissDoesNotClearNode() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:93 |     @Test func labyrinthMysteryFinishClearsNode() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:108 |     @Test func startLabyrinthBattleSetsInMemoryOrigin() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:116 |     @Test func labyrinthRestFinishClearsNode() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:131 |     @Test func labyrinthCraftForgeClearsNodeWhenAffordable() throws { | keep |
| TrinketTests/App/AppStateLabyrinthTests.swift:147 |     @Test func legacyEventNodeRoutesToMystery() throws { | keep |
| TrinketUITests/Smoke/SmokeShopTests.swift:4 |     func testMerchantShopBrowseDetailAndLeave() { | keep |
| TrinketUITests/Smoke/SmokeHomesteadTests.swift:8 |     func testHomesteadOverviewShowsWalletCategoriesAndRepresentativeRows() { | keep |
| TrinketUITests/Smoke/SmokeHomesteadTests.swift:17 |     func testLockedProjectsRemainVisibleButDoNotOpenDetail() { | keep |
| TrinketUITests/Smoke/SmokeHomesteadTests.swift:31 |     func testWheatFieldDetailRetainsTabBarAndNativeBackNavigation() { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AspectCatalogTests.swift:7 |     @Test func damageAspectsAreAuthored() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AspectCatalogTests.swift:17 |     @Test func floorsResolveExistingEnemies() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AspectCatalogTests.swift:28 |     @Test func attunementRequiresMatchingAbilityKeywords() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AspectCatalogTests.swift:41 |     @Test func everyAspectHasAttunableHeroAndCompanion() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerHomesteadStoreTests.swift:14 |     @Test func buildOrUpgradeNodePersistsHomesteadAndRosterThroughHub() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerHomesteadStoreTests.swift:37 |     @Test func buildOrUpgradeNodeReturnsInsufficientResourcesWithoutMutating() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/ShopPurchaseApplierTests.swift:8 |     @Test func purchaseSpendsGoldAndGrantsItem() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/ShopPurchaseApplierTests.swift:37 |     @Test func purchaseFailsWithoutSpendingWhenGoldIsInsufficient() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/ShopPurchaseApplierTests.swift:54 |     @Test func repeatedPurchaseOfSameOfferInSameVisitIsAlreadyOwned() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/ShopPurchaseApplierTests.swift:81 |     @Test func differentVisitTokensMintDistinctInstanceIDs() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:16 |     @Test func startBattleConfiguresActiveBattleWhenStageIsValid() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:28 |     @Test func startBattleIgnoresRequestWhenBattleAlreadyActive() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:40 |     @Test func setMusicPreviewUsesBattleEncounterWhenStageHasBattle() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:50 |     @Test func restartBattleRefreshesProgressionFromRosterWhenRosterUpdated() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:65 |     @Test func presentCombatantDetailSetsOverlayWithoutActiveBattle() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:80 |     @Test func endBattleClearsSessionStateWhenBattleEnds() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:98 |     @Test func presentBattleLogSetsFlagAndSyncsLog() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:118 |     @Test func startBattleReturnsMessageWhenEnemyMissing() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:136 |     @Test func restartBattleRebuildsActiveConfigurationWhenBattleActive() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:150 |     @Test func presentAbilityDetailSetsOverlayWhenBattleActive() throws { | keep |
| TrinketTests/Battle/BattleSessionAppIntegrationTests.swift:162 |     @Test func musicPreviewClearsForActiveBattleAndNonBattleStage() throws { | keep |
| TrinketTests/App/AppStateMysteryRecruitTests.swift:16 |     @Test func mysteryRecruitStageOpensEncounterAndUnlocksOnWelcome() throws { | keep |
| TrinketTests/App/AppStateMysteryRecruitTests.swift:42 |     @Test func alreadyUnlockedRecruitStageAutoCompletesWhenNoSubstitutesRemain() throws { | keep |
| TrinketTests/App/AppStateMysteryRecruitTests.swift:57 |     @Test func dismissMysteryEncounterDoesNotCompleteStage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersTickTests.swift:7 |     @Test func decayingDoTTicksUseSemanticDecayRules() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersTickTests.swift:40 |     @Test func defaultTickLeavesDurationlessBlockUntouched() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersTickTests.swift:49 |     @Test func mitigationTickLeavesDurationlessArmorUntouched() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersTickTests.swift:63 |     @Test func leechTickDecrementsRemainingDuration() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/CombatantModelTests.swift:6 |     @Test func combatantDefaultsToZeroPrimaryStats() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/MysteryEffectApplierTests.swift:20 |     @Test func applyingGoldMaterialsAndExperienceMutatesSave() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/MysteryEffectApplierTests.swift:47 |     @Test func generatedItemIncludesGuaranteedAffixAndUsesRolledRarity() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/MysteryEffectApplierTests.swift:68 |     @Test func gainRandomItemAppendsOneInventoryItem() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/MysteryEffectApplierTests.swift:86 |     @Test func chooseItemReturnsCandidatesWithoutGranting() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/MysteryEffectApplierTests.swift:109 |     @Test func manaBerryHarvestChoiceAppliesExpectedRewards() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/MysteryEffectApplierTests.swift:131 |     @Test func unlockCombatantEffectsHandleHeroAndCompanionIdempotently() throws { | keep |
| TrinketTests/App/AppStateShopEncounterTests.swift:16 |     @Test func shopStageOpensEncounterWithOffers() throws { | keep |
| TrinketTests/App/AppStateShopEncounterTests.swift:29 |     @Test func purchasingOfferSpendsGoldAndGrantsItem() throws { | keep |
| TrinketTests/App/AppStateShopEncounterTests.swift:50 |     @Test func purchaseFailsWhenGoldIsInsufficient() throws { | keep |
| TrinketTests/App/AppStateShopEncounterTests.swift:70 |     @Test func purchaseSucceedsWhenGoldEqualsPrice() throws { | keep |
| TrinketTests/App/AppStateShopEncounterTests.swift:86 |     @Test func sameOfferCannotBePurchasedTwiceInOneVisit() throws { | keep |
| TrinketTests/App/AppStateShopEncounterTests.swift:106 |     @Test func reopeningShopAfterPurchaseDoesNotBurnGoldOnSameOffer() throws { | keep |
| TrinketTests/App/AppStateShopEncounterTests.swift:136 |     @Test func finishShopEncounterCompletesStageWithoutFreeItemReward() throws { | keep |
| TrinketTests/App/AppStateShopEncounterTests.swift:156 |     @Test func dismissShopEncounterDoesNotCompleteStage() throws { | keep |
| TrinketTests/App/AppStateShopEncounterTests.swift:170 |     @Test func mysteryEncounterDoesNotOpenWhileShopIsActive() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/AbilityDescriptionFormatterTests.swift:5 |     @Test func representativeAbilityDescriptionsPreserveSemanticFormatting() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleSimulatorTests.swift:7 |     @Test func greedyPolicyReachesOutcomeDeterministically() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleSimulatorTests.swift:29 |     @Test func tracksEventsFalseKeepsEventLogEmpty() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleSimulatorTests.swift:52 |     @Test func midTierGearUsesBuildAlignedAffixesOnly() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleSimulatorTests.swift:77 |     @Test func earlyTierOmitsUltimateWhenLocked() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleSimulatorTests.swift:86 |     @Test func identitySweepProducesMarkdownWithSecondaryMetrics() { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleSimulatorTests.swift:103 |     @Test func parallelIdentityMatchesSequentialOutcomes() { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleSimulatorTests.swift:126 |     @Test func abilityContrastProducesLiftRows() { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleSimulatorTests.swift:142 |     @Test func affixContrastProducesLiftRowsOnMidTier() { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleSimulatorTests.swift:157 |     @Test func wilsonIntervalContainsPointEstimate() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/AspectsProgressTests.swift:9 |     @Test func markFloorClearedAdvancesSequentiallyOnly() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/AspectsProgressTests.swift:24 |     @Test func sanitizeDropsUnknownAspectsAndClampsFloors() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/AspectsProgressTests.swift:36 |     @Test @MainActor func aspectsProgressPersistsThroughStore() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/AspectsProgressTests.swift:52 |     @Test func aspectCompletionGrantsGoldAndProgress() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/AspectsProgressTests.swift:73 |     @Test func floorCompletionGrantsBiasedItemAndIsIdempotent() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/AspectsProgressTests.swift:106 |     @Test func wardenCompletionGrantsBiasedItem() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/AspectsProgressTests.swift:135 |     @Test func unlockGatesFollowIronVeinProgress() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/AspectsProgressTests.swift:153 |     @Test func unlockAllClearsEveryAspectClimb() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/AspectsProgressTests.swift:163 |     @Test func materialBiasMatchesAspectKeyword() throws { | keep |
| TrinketUITests/Smoke/SmokeBattleTests.swift:8 |     func testBattleLaunchScreenStartsStageOneOne() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:9 |     @Test(arguments: [CGFloat(375), 390, 430]) | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:21 |     @Test func compactScreensScaleWithoutNegativeSizes() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:31 |     @Test func veryShortScreensKeepNonNegativeCardSizes() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:38 |     @Test(arguments: [ | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:105 |     @Test func singleCardCentersWithinWidthClamps() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:115 |     @Test func fiveCardsUseSymmetricFan() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:130 |     @Test(arguments: [CGFloat(375), 390, 430]) | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:140 |     @Test func upwardReleasePastThresholdPlays() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:148 |     @Test func projectedUpwardFlickPlaysBeforeTranslationReachesThreshold() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:156 |     @Test func playZoneArmingUsesActualTranslationUntilDirectionalThreshold() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:177 |     @Test func armedPlayZoneUsesHysteresisWhenFingerMovesBackTowardBoundary() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:206 |     @Test func sidewaysDownwardAndUnplayableReleasesReturn() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:224 |     @Test func unplayableUpwardDragRubberBandsPastThreshold() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:239 |     @Test func heldTiltIsBoundedAndRespondsToHorizontalDirection() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:259 |     @Test func readinessTargetRoutesEnemyOwnerAndExplicitTargets() { | keep |
| TrinketTests/Battle/BattleCardGridLayoutTests.swift:311 |     @Test func readinessTargetChoosesLowestHealthAllyAndKeepsOffensiveMixedIntent() { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleOutcomeResolverTests.swift:7 |     @Test func simultaneousDefeatResolvesAsVictory() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleOutcomeResolverTests.swift:13 |     @Test func partyDefeatResolvesAsDefeat() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleOutcomeResolverTests.swift:19 |     @Test func enemyDefeatResolvesAsVictory() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleOutcomeResolverTests.swift:25 |     @Test func ongoingBattleReturnsNil() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:33 |     @Test func completingStageGrantsBattleGoldWithStageRewards() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:50 |     @Test func completingStageGrantsGoldXPAndItems() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:91 |     @Test func materialRewardsAreUnchangedByHomesteadTiers() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:112 |     @Test func wishingWellIncreasesGrantedGold() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:136 |     @Test func completingStageTwiceDoesNotDoubleRewards() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:164 |     @Test func completingStageAdvancesJourney() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:181 |     @Test func missingItemTemplateSkipsGracefully() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:210 |     @Test func nonBattleStagesGrantNoExperience() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:227 |     @Test func scaledExperienceGrantsNothingWhenEnemyIsFarBelowPlayer() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:246 |     @Test func claimRewardsIfNeededIsIdempotentWhenCalledTwice() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:276 |     @Test func rewardItemPreservesCatalogAffixes() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/StageRewardTests.swift:287 |     @Test func claimRewardsUsesPrecomputedMaterialRewards() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersTests.swift:7 |     @Test func registryKeysMatchAllEffectKinds() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersTests.swift:11 |     @Test(arguments: EffectKind.allCases) | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:8 |     @Test func headerHeightMatchesThreeToFourAspect() { | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:15 |     @Test func headerHeightHasMinimumOf300() { | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:21 |     @Test func headerHeightAtMinimumThreshold() { | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:27 |     @Test func headerHeightAboveMinimumUsesWidth() { | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:33 |     @Test func headerHeightForCommonDeviceWidths() { | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:48 |     @Test func cinematicHeightIsDenseAndClamped() { | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:56 |     @Test func overscrollIsZeroWhenContentIsNotPulledPastTop() { | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:61 |     @Test func overscrollUsesNegativeAdjustedContentOffset() { | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:66 |     @Test func overscrollMetricsExpandHeightAndPinTopEdge() { | keep |
| TrinketTests/Collection/HeroHeaderLayoutTests.swift:73 |     @Test func overscrollMetricsDoNotMoveAtRest() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:7 |     @Test func setLoadoutOverridesDefaultAbilityChoices() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:23 |     @Test func battleConfiguredCombatantFiltersLockedPlayerAbilityTiers() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:42 |     @Test func battleConfiguredCombatantRestoresPlayerAbilityTiersAtUnlockLevels() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:61 |     @Test func battleConfiguredCombatantDoesNotFilterEnemyAbilities() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:70 |     @Test func setActiveCombatantsIgnoresLockedEntriesOnFreshStart() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:81 |     @Test func goldMutationRulesRespectBounds() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:98 |     @Test func spendGoldDeductsWhenAffordable() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:107 |     @Test func spendGoldRejectsInsufficientOrNonPositiveAmounts() { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:120 |     @Test func equippedItemResolvesFromInventoryAndLoadout() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:131 |     @Test func equipmentLoadoutEquipAndUnequip() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:142 |     @Test func setEquipmentLoadoutUnequipsItemFromOtherCombatants() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:160 |     @Test func inventorySlotUnlocksWhenSlotItemExists() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:173 |     @Test func highestLevelsFilterByRoleAndDefaultToOne() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:188 |     @Test func collectionCombatantsPlaceUnlockedEntriesFirstAndSortThemByLevel() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:215 |     @Test func unlockCombatantsSeedsProgressionAndIsIdempotent() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:233 |     @Test func unlockIgnoresUnknownAndEnemyIDs() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:244 |     @Test func unlockAllCombatantsGrantsCatalogAtRequestedLevel() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift:260 |     @Test func addRewardItemIgnoresDuplicateID() throws { | keep |
| TrinketTests/Battle/CombatFeedbackPresenterTests.swift:9 |     @Test func dropsZeroDamageAbilityChips() { | keep |
| TrinketTests/Battle/CombatFeedbackPresenterTests.swift:20 |     @Test func mergesCriticalIntoDamageChip() { | keep |
| TrinketTests/Battle/CombatFeedbackPresenterTests.swift:39 |     @Test func classifiesStatusAsDotWithShorterLifetime() { | keep |
| TrinketTests/Battle/CombatFeedbackPresenterTests.swift:50 |     @Test func classifiesHealAndDodge() { | keep |
| TrinketTests/Battle/CombatFeedbackPresenterTests.swift:73 |     @Test func staggerOffsetsAvailability() { | keep |
| TrinketTests/Battle/CombatFeedbackPresenterTests.swift:88 |     @Test func layoutJitterIsDeterministic() { | keep |
| TrinketTests/Battle/CombatFeedbackPresenterTests.swift:97 |     @Test func burstsSkipUtilityClasses() { | keep |
| TrinketTests/Battle/BattleVictorySummaryTests.swift:11 |     @Test func makeVictorySummaryIncludesStageAndBattleRewardsWhenVictory() throws { | keep |
| TrinketTests/Battle/BattleVictorySummaryTests.swift:57 |     @Test func makeVictorySummaryScalesExperienceWhenEncounterLevelDiffers() throws { | keep |
| TrinketTests/Battle/BattleVictorySummaryTests.swift:97 |     @Test func makeVictorySummaryIncludesBattleGoldWhenRewardsGranted() throws { | keep |
| TrinketTests/Battle/BattleVictorySummaryTests.swift:135 |     @Test func makeVictorySummaryAppliesHomesteadBonusesWhenBonusesActive() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/HomesteadStateTests.swift:7 |     @Test func buildOrUpgradeSpendsMaterialsAndGold() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/HomesteadStateTests.swift:25 |     @Test func buildOrUpgradeSpendsGoldWhenCostRequiresIt() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/HomesteadStateTests.swift:43 |     @Test func lockedNodeCannotUpgradeBeforePrerequisites() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/HomesteadStateTests.swift:57 |     @Test func effectsReplaceLowerTiersInsteadOfStacking() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/HomesteadStateTests.swift:65 |     @Test func wishingWellIncreasesGoldFindPercent() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/HomesteadStateTests.swift:71 |     @Test func detectMagicIncreasesAstralChancePercent() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/HomesteadStateTests.swift:76 |     @Test func grantCapsMaterialBalanceAtMax() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleTurnEngineTests.swift:43 |     @Test func consumeActionSkipEmitsControlActionSkippedAndRemovesEffect() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleTurnEngineTests.swift:55 |     @Test func consumeActionSkipRecordsAction() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleTurnEngineTests.swift:68 |     @Test func performAbilityResolvesWhenNoSkipPending() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleTurnEngineTests.swift:84 |     @Test func deathgripDoesNotFireOnSkippedAction() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleTurnEngineTests.swift:129 |     @Test func abilityEventIncludesActorAbilityAndTier() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleTurnEngineTests.swift:148 |     @Test func performAbilitySkipsCorpseTargetedEffectsAfterLethalHit() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleTurnEngineTests.swift:203 |     @Test func performAbilityStillGrantsGoldAfterLethalHit() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleTurnEngineTests.swift:252 |     @Test func preferredTierFollowsEnemyCadence() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ConditionalDoTDedupTests.swift:7 |     @Test func shouldSkipImmediateDoTWhenKeywordMatchesRegardlessOfPotency() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ConditionalDoTDedupTests.swift:12 |     @Test func burnHandlerSkipsImmediateDamageWhenBoostedPairedBurnExists() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ConditionalDoTDedupTests.swift:31 |     @Test func poisonHandlerSkipsImmediateDamageWhenBoostedPairedPoisonExists() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:6 |     @Test func allMysteryEventsHaveUniqueIDs() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:11 |     @Test func branchingMysteryEventsHaveTwoChoices() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:21 |     @Test func recruitMysteryEventsHaveOneUnlockChoice() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:37 |     @Test func recruitEventsCoverEveryNonStarterCombatantExactlyOnce() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:47 |     @Test func allMysteryEventsHaveUniqueChoiceIDs() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:57 |     @Test func allMysteryEventsHaveAtLeastOneEffectPerChoice() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:65 |     @Test func artReferencesAreValid() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:75 |     @Test func recruitEventsResolveCombatantArt() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:85 |     @Test func mysteryEventLookupHandlesKnownAndUnknownIDs() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:93 |     @Test func pickMysteryEventReturnsValidBranchingEvent() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:99 |     @Test func pickEligibleMysteryEventPrefersLockedRecruits() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:111 |     @Test func pickEligibleMysteryEventFallsBackWhenAllUnlocked() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:122 |     @Test func generatedItemEffectsReferenceKnownBaseTypes() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:145 |     @Test func manaBerryHarvestGrantsHerbsAndManaboundSapphireRing() throws { | keep |
| Packages/TrinketContent/Tests/TrinketContentTests/MysteryEventCatalogTests.swift:156 |     @Test func mysteryEffectsNeverSpendResources() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/MitigationIntegrationTests.swift:8 |     @Test func shieldAbsorbsDamageBeforeHealth() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/MitigationIntegrationTests.swift:26 |     @Test func armorMitigatesIncomingDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/MitigationIntegrationTests.swift:47 |     @Test func effectiveDamageMatchesEventAmount() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/MitigationIntegrationTests.swift:69 |     @Test func sunderArmorHalvesEnemyArmor() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTDamageTests.swift:36 |     @Test func resolveTickStoresBasePotencyOnStack() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTDamageTests.swift:50 |     @Test func resolveTickAppliesStatBonusAtDamageTime() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTDamageTests.swift:64 |     @Test func resolveTickAppliesItemDamageDealtBonus() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DoTDamageTests.swift:78 |     @Test func resolveTickIncludesStatusEventWhenDamageDealt() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerShellSessionStoreTests.swift:19 |     @Test func roundTripMatrixPersistsAndResetsShellState() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerShellSessionStoreTests.swift:42 |     @Test func legacyMigrationMatrixRemapsAndCleansLegacyState() throws { | keep |
| Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerShellSessionStoreTests.swift:78 |     @Test func clearsStaleBattleResumeFieldsOnLoad() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/StatIntegrationTests.swift:21 |     @Test func statBonusAppliedToDirectDamageKeywords() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/StatIntegrationTests.swift:53 |     @Test func toughnessMitigationReducesIncomingDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/StatIntegrationTests.swift:82 |     @Test func toughnessReducesFireballAndBurnDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/StatIntegrationTests.swift:108 |     @Test func wisdomIncreasesHealingAmount() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/StatIntegrationTests.swift:141 |     @Test func agilityRaisesControlMeterThresholdInBattle() throws { | keep |
| TrinketTests/Battle/BattleSpectacleSessionTests.swift:13 |     @Test func playingSkillCardShowsCallout() throws { | keep |
| TrinketTests/Battle/BattleSpectacleSessionTests.swift:44 |     @Test func playingHeroUltimateDefersFeedbackUntilCinematicCompletes() throws { | keep |
| TrinketTests/Battle/BattleSpectacleSessionTests.swift:107 |     @Test func oncePerBattleShowsHeroUltimateOnceThenAutoSkips() throws { | keep |
| TrinketTests/Battle/BattleSpectacleSessionTests.swift:159 |     @Test func enemyUltimateUsesSkillCalloutNotCinematic() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/RestorationIntegrationTests.swift:8 |     @Test func instantHealRestoresHealth() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/RestorationIntegrationTests.swift:41 |     @Test func leechHealsAttackerOnDamageDealt() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/RestorationIntegrationTests.swift:74 |     @Test func enemyInstantHealRestoresHealthWhenBelowMax() throws { | keep |
| TrinketTests/Battle/ActiveBattleConfigurationTests.swift:8 |     @Test func makeWithoutEquipmentUsesTraitOnlyModifiers() throws { | keep |
| TrinketTests/Battle/ActiveBattleConfigurationTests.swift:28 |     @Test func makeResolvesEquippedItemModifiers() throws { | keep |
| TrinketTests/Battle/ActiveBattleConfigurationTests.swift:59 |     @Test func makeResolvesEnemyTraitModifiers() throws { | keep |
| TrinketTests/Battle/ActiveBattleConfigurationTests.swift:75 |     @Test func makePreservesStageMetadata() throws { | keep |
| TrinketTests/Battle/ActiveBattleConfigurationTests.swift:100 |     @Test func resolvedEncounterScalesEnemyToJourneyLevel() throws { | keep |
| TrinketTests/Battle/ActiveBattleConfigurationTests.swift:110 |     @Test func makePreservesJourneyScaledEnemyStats() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectSummaryBuilderTests.swift:9 |     @Test func burnStackYieldsActiveSummary() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectSummaryBuilderTests.swift:19 |     @Test func bleedStacksSummed() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectSummaryBuilderTests.swift:31 |     @Test func shieldSummary() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectSummaryBuilderTests.swift:41 |     @Test func stunBuildupSummary() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectSummaryBuilderTests.swift:49 |     @Test func triggeredStunBuildupSummary() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectSummaryBuilderTests.swift:59 |     @Test func leechSummary() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectSummaryBuilderTests.swift:67 |     @Test func deathsDoorSummary() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectSummaryBuilderTests.swift:81 |     @Test func emptyEffectsProducesEmptySummaries() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectSummaryBuilderTests.swift:87 |     @Test func multipleKeywordsYieldMultipleSummaries() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CleanseIntegrationTests.swift:8 |     @Test func cleanseAllRemovesDebuffsWhenAbilityFires() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CleanseIntegrationTests.swift:33 |     @Test func cleanseSpecificKeywordRemovesMatchingDebuffsOnUse() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CleanseIntegrationTests.swift:73 |     @Test func cleanseAllRemovesAllDebuffsButLeavesShields() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CleanseIntegrationTests.swift:119 |     @Test func cleanseStunRemovesControlMeterBuildup() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatOutcomeTests.swift:30 |     @Test func resolveDamageReturnsCombatOutcome() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatOutcomeTests.swift:45 |     @Test func resolveDamageSetsDodgedFlag() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatOutcomeTests.swift:81 |     @Test func resolveDamageSetsLeechedFlag() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatOutcomeTests.swift:98 |     @Test func damageRequestDoTTickPresetAppliesBonusesWithoutDodge() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatOutcomeTests.swift:110 |     @Test func damageRequestDirectAbilityHitUsesDefaultOptions() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatOutcomeTests.swift:120 |     @Test func resolveHealReturnsRestoredAmount() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:12 |     @Test func playCardShowsVictorySummaryWhenEnemyDefeated() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:29 |     @Test func playCardCompletesImmediatelyWhenStageRewardsAlreadyClaimed() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:50 |     @Test func endTurnDoesNothingWhenBattleAlreadyOver() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:63 |     @Test func clearOutcomePresentationResetsVictoryAndDefeatFlagsWhenCleared() { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:89 |     @Test func playCardAppendsNonMilestoneEventsWhenCardPlays() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:99 |     @Test func endTurnExcludesMilestonesWhenBattleEnds() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:118 |     @Test func resetClearsFeedbackAndRebuildsStateWhenResetCalled() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:143 |     @Test func removeFeedbackEventRemovesByIDWhenMatchingID() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:155 |     @Test func pruneExpiredFeedbackRemovesEventsWhenPastDisplayDuration() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:170 |     @Test func outcomeReportsOngoingWhenBattleInProgress() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:179 |     @Test func outcomeReportsVictoryWhenEnemyDefeated() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:188 |     @Test func outcomeReportsDefeatWhenPartyDefeated() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:204 |     @Test func outcomeReportsVictoryWhenFaustianBargainDefeatsEnemyAndCompanionSurvives() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:235 |     @Test func outcomeReportsVictoryWhenEnemyAndPartyDefeatedTogether() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:246 |     @Test func resetPreservesEnemyModifiersWhenBattleReset() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:269 |     @Test func openingHandIsDealtAndCanEndTurnWhilePlayerTurn() throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:277 |     @Test func autoEndsTurnAfterDelayWhenNoPlayableCardsRemain() async throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:301 |     @Test func doesNotAutoEndTurnWhilePlayableCardsRemain() async throws { | keep |
| TrinketTests/Battle/BattleSessionSimulationTests.swift:313 |     @Test func trimMemoryFootprintReleasesBattleLogProjection() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyStatusTests.swift:10 |     @Test func cleanseSpecificKeywordRemovesMatchingEffects() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyStatusTests.swift:23 |     @Test func cleanseAllRemovesAllDebuffs() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyStatusTests.swift:46 |     @Test func cleanseStunRemovesActivePrevention() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyStatusTests.swift:58 |     @Test func cleanseRandomRemovesOneDebuff() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyStatusTests.swift:77 |     @Test func purgeSpecificKeywordRemovesMatchingBuffs() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyStatusTests.swift:102 |     @Test func purgeAllRemovesBuffsButLeavesDebuffs() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyStatusTests.swift:119 |     @Test func purgeRandomRemovesOneBuff() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleConditionEvaluatorTests.swift:8 |     @Test func lowestHealthAllyPrefersLivingCombatantWhenHeroIsDefeated() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleConditionEvaluatorTests.swift:40 |     @Test func enemyBleedingRequiresActiveBleedStack() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HomesteadCombatModifierTests.swift:7 |     @Test func flatFreezeReductionLowersIncomingFreezeDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HomesteadCombatModifierTests.swift:17 |     @Test func manaCostReductionRoundsDownAndAllowsZero() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:10 |     @Test func burnHandlerAppliesBurnEffect() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:18 |     @Test func burnHandlerSkipsInitialDamageWhenPaired() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:40 |     @Test func shieldHandlerAddsShieldAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:53 |     @Test func mitigationHandlerAddsMitigationAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:66 |     @Test func leechHandlerAddsLeechEffectAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:74 |     @Test func leechHandlerReplacesExistingLeechInsteadOfStacking() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:83 |     @Test func drawCardsHandlerDrawsIntoHandAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:117 |     @Test func drawCardsHandlerOverflowGoesToBuffer() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:148 |     @Test func cleanseWithoutDebuffsDoesNotApply() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyTests.swift:157 |     @Test func resourceGainHandlerAddsGold() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterIntegrationTests.swift:13 |     @Test func actionSkipPreventsDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterIntegrationTests.swift:27 |     @Test func actionSkipConsumesOnEnemyTurn() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterIntegrationTests.swift:38 |     @Test func stunDamageBuildsMeterTriggersAndSkipsNextAction() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterIntegrationTests.swift:63 |     @Test func shieldBashAppliesStunSkipAndBlock() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterIntegrationTests.swift:88 |     @Test func partyOwnerSkipBlocksCardPlayThenClearsOnEndTurn() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:45 |     @Test func openingHandDrawsThreeCardsFromRandomOwners() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:63 |     @Test func playPutsCardOnBottomOfOwnerDeck() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:82 |     @Test func darkPactDrawsTwoCardsForOwner() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:114 |     @Test func endTurnAtFullHandDrawsIntoBuffer() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:139 |     @Test func playingCardPromotesOldestBufferedCardFIFO() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:169 |     @Test func automaticOpenSlotGoesToOwnerWithFewerCards() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:196 |     @Test(arguments: [(0, BattleParticipant.companion), (1, BattleParticipant.hero)]) | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:224 |     @Test func enemyCadenceUsesBasicSkillAndUltimate() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:246 |     @Test func endOfRoundTicksEffectsOnce() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:266 |     @Test func deadOwnerCardsAreUnplayable() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleCardCombatTests.swift:286 |     @Test func manaCostIgnoredWhenPlayingCards() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleRosterTests.swift:50 |     @Test func effectTickOrderIsEnemyHeroCompanion() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleRosterTests.swift:54 |     @Test func matchupCombatantForParticipant() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleRosterTests.swift:65 |     @Test func runtimeForReturnsMatching() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleRosterTests.swift:76 |     @Test func combatantForReturnsRuntimeByID() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleRosterTests.swift:84 |     @Test func updateReplacesMatchingRuntime() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleRosterTests.swift:96 |     @Test func activeEffectsAndSetActiveEffects() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleRosterTests.swift:109 |     @Test func enemyAttackTargetCoversAliveDeadAndHealthPriority() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleRosterTests.swift:127 |     @Test func isPartyDefeatedRequiresBothDown() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleRosterTests.swift:142 |     @Test func isEnemyDefeated() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DamagePipelineTests.swift:48 |     @Test func registryCanonicalNamesMatchExpectedOrder() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DamagePipelineTests.swift:52 |     @Test func executedStepNamesMatchCanonicalOrderForFullHit() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DamagePipelineTests.swift:66 |     @Test func executedStepNamesShortCircuitAfterDodge() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DamagePipelineTests.swift:103 |     @Test func stepPhasesGroupStochasticResolutionAndPost() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatBuildResolverTests.swift:7 |     @Test func equippedStatAffixesMergeIntoEffectiveStats() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatBuildResolverTests.swift:33 |     @Test func equippedDamageAffixesAggregateIntoModifierProfile() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatBuildResolverTests.swift:60 |     @Test func multipleEquippedItemsStackModifiers() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatBuildResolverTests.swift:97 |     @Test func traitModifiersMergeIntoBuildProfile() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterEngineTests.swift:36 |     @Test func applyBuildupTriggersControlAtThreshold() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterEngineTests.swift:48 |     @Test func applyBuildupNoDuplicateWhenSameKeywordSkipPending() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterEngineTests.swift:65 |     @Test func applyBuildupAccumulatesOtherKeywordWhileSkipPending() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterEngineTests.swift:92 |     @Test func stunAndFreezeMetersCoexistOnSameTarget() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterEngineTests.swift:105 |     @Test func contextControlMeterDelegatesToControlMeterEngine() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterEngineTests.swift:122 |     @Test func overflowChargeIsConsumedOnTrigger() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:32 |     @Test func applyDamageDodgeReturnsZeroWhenRollSucceeds() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:41 |     @Test func applyDamageDodgeDoesNotTriggerWhenNoSourceActor() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:47 |     @Test func applyDamageDodgeDoesNotTriggerWhenApplyDodgeFalse() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:55 |     @Test func applyDamageShieldAbsorptionPreservesSourceActorID() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:76 |     @Test func applyDamageStatBonusAppliesForSource() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:86 |     @Test func applyLeechFromDamageNoLeechEffectNoHeal() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:93 |     @Test func applyLeechFromDamageWithLeechEffectHealsSource() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:105 |     @Test func applyLeechFromDamageWithAbilityKeywordHealsSource() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:116 |     @Test func stunAndFreezeBuildupTrackedSeparatelyFromDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:136 |     @Test func applyDoTDamageAppliesLeechWhenSourceActorPresent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:148 |     @Test func applyDamageTriggersLeechOnDirectHit() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:164 |     @Test func applyDamageDoesNotLeechOnSelfDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:182 |     @Test func preventionThresholdUsesItemMaximumHealthBonus() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:215 |     @Test func stunBuildupUsesPostMitigationDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:231 |     @Test func stunBuildupAppliesWhenShieldAbsorbsAllDamage() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:249 |     @Test func criticalHitIsAbsorbedByShieldBeforeHealth() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:272 |     @Test func damageStepsRunInCanonicalOrder() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift:292 |     @Test func thornsRetaliationDoesNotRecurse() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ActionEventFormatterTests.swift:31 |     @Test func abilityDamageFormatsAsNegativeAmount() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ActionEventFormatterTests.swift:40 |     @Test func instantHealFormatsAsPositiveWithKeyword() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ActionEventFormatterTests.swift:48 |     @Test func controlTriggeredUsesStatusAlias() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/ActionEventFormatterTests.swift:56 |     @Test func secondaryTextIsAlwaysNil() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:7 |     @Test func noDamageNoEffectsFallsBackToShortForm() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:19 |     @Test func damageOnlyShowsDamageForm() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:31 |     @Test func effectsOnlyShowsOnForm() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:43 |     @Test func damageAndEffectsCombines() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:55 |     @Test func multipleEffectsJoinedByComma() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:67 |     @Test func entriesReduceMilestonesStatusAndAbilityEvents() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:127 |     @Test func incrementalEntriesMatchFullRebuild() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:173 |     @Test func logProjectionIncrementalSyncMatchesFullReduce() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:209 |     @Test func deathsDoorTriggeredLogLine() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleLogReducerTests.swift:224 |     @Test func deathsDoorExpiredLogLine() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:10 |     @Test func halveMitigationHandlerHalvesArmorAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:28 |     @Test func halveMitigationHandlerReportsNoApplyWhenArmorMissing() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:41 |     @Test func burnHandlerDoesNotApplyToDefeatedTarget() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:58 |     @Test func deathsDoorHandlerApplyIsNoOp() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:73 |     @Test func hasteHandlerIsNoOpInCardCombat() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:97 |     @Test func thornsHandlerAppliesThornsAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:126 |     @Test func markedHandlerAppliesMarkedAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:149 |     @Test func markedHandlerReplacesExistingMarkInsteadOfStacking() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:181 |     @Test func criticalChanceBonusHandlerAppliesBonusAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:202 |     @Test func restoreManaOnHitHandlerAppliesBuffAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectHandlersApplyBuffDebuffTests.swift:223 |     @Test func damageKeywordOverrideHandlerAppliesBuffAndEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:17 |     @Test func openingHandDrawsThreeCards() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:32 |     @Test func enemyAttackTargetPrefersHigherHealthMember() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:38 |     @Test func enemyTargetsCompanionWhenHeroDead() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:52 |     @Test func partyDefeatWhenBothHeroAndCompanionDie() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:64 |     @Test func partyNotDefeatedWhenOneMemberOnDeathsDoor() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:84 |     @Test func partyDefeatWhenBothDeathsDoorConsumedAndExpired() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:113 |     @Test func battleGoldTracksInitialBalanceAndResourceGains() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:134 |     @Test func cardCombatVictoryWhenEnemyDies() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:148 |     @Test func cardCombatDefeatWhenPartyObliterated() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:162 |     @Test func seededEffectsDoNotCollideWithNewEffectIDs() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:187 |     @Test func battleEndsWhenHeroKillsEnemyWithoutFurtherPlays() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:204 |     @Test func faustianBargainSelfDamageDoesNotWipePartyWhenCompanionSurvives() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift:238 |     @Test func rosterContextInitPreservesRngSeed() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:36 |     @Test func triggerOnFirstLethalHit() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:56 |     @Test func enemyNeverTriggers() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:71 |     @Test func protectionClampsToOneWhileActive() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:81 |     @Test func secondLethalAfterExpiryKills() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:102 |     @Test func lethalHitSameTickAfterExpiryStillClampsToOne() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:121 |     @Test func secondWindDoesNotPreemptDeathsDoorOnLethalHit() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:145 |     @Test func heroAndCompanionProcIndependently() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:159 |     @Test func effectInsertedAtFrontOfActiveEffects() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:174 |     @Test func doTTickTriggersDeathsDoor() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/DeathsDoorEngineTests.swift:189 |     @Test func overkillShowsActualHPLost() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:28 |     @Test func initialHealthAccountsForToughness() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:35 |     @Test func initialHealthUsesProvidedOverride() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:41 |     @Test func initialActiveEffectsAreStored() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:48 |     @Test func initialManaAccountsForIntellect() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:65 |     @Test func healthMutationRulesRespectBoundsAndBonuses() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:102 |     @Test func manaMutationRulesRespectBounds() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:127 |     @Test func markActedIncrementsActionCount() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:141 |     @Test func setEffectsReplacesEntireArray() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:151 |     @Test func removeEffectsFiltersByPredicate() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantRuntimeTests.swift:166 |     @Test func identityPassthrough() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectTickEngineTests.swift:35 |     @Test func doTTickPreservesShieldDepletionThroughTickAll() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/EffectTickEngineTests.swift:61 |     @Test func doTTickPreservesDeathsDoorThroughTickAll() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantLevelScalerTests.swift:7 |     @Test func playerScalerAtLevelOneMatchesIdentity() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantLevelScalerTests.swift:15 |     @Test func playerScalerIncreasesHealthAboveEnemyAtSameLevel() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/CombatantLevelScalerTests.swift:26 |     @Test func enemyScalerUsesBossProfile() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HealingEngineTests.swift:30 |     @Test func resolveHealSilentEmitsNoEvents() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HealingEngineTests.swift:41 |     @Test func resolveHealInstantHealPolicyEmitsEvent() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HealingEngineTests.swift:63 |     @Test func leechFromDamageHealsAndSetsLeechedFlag() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HealingEngineTests.swift:76 |     @Test func abilityLeechHealsHalfOfDamageDealt() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HealingEngineTests.swift:91 |     @Test func leechFromDamageDoesNotReviveDefeatedSource() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HealingEngineTests.swift:101 |     @Test func resolveHealIgnoresDefeatedTarget() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HealingEngineTests.swift:112 |     @Test func healFromOneHPWhileDeathsDoorActive() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HealingEngineTests.swift:128 |     @Test func healDoesNotRemoveDeathsDoorEffect() throws { | keep |
| Packages/BattleEngine/Tests/BattleEngineTests/HealingEngineTests.swift:146 |     @Test func contextResolveHealDelegatesToHealingEngine() throws { | keep |
