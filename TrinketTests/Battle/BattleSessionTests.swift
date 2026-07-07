import TrinketContent
import TrinketCore
import TrinketPersistence
import XCTest
@testable import BattleEngine
@testable import Trinket

// swiftlint:disable file_length type_body_length
@MainActor
final class BattleSessionTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BattleSessionTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directoryURL)
        try await super.tearDown()
    }

    func testStartBattleConfiguresActiveBattleWhenStageIsValid() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)

        let message = appState.startBattle(for: stage)

        XCTAssertNil(message)
        let activeBattle = try XCTUnwrap(appState.battle.activeBattle)
        XCTAssertEqual(activeBattle.stageID, stage.id)
        XCTAssertNil(appState.battle.preview)
    }

    func testStartBattleIgnoresRequestWhenBattleAlreadyActive() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        let firstBattleID = try XCTUnwrap(appState.battle.activeBattle?.id)

        let message = appState.startBattle(for: stage)

        XCTAssertNil(message)
        XCTAssertEqual(appState.battle.activeBattle?.id, firstBattleID)
    }

    func testSetMusicPreviewUsesBattleEncounterWhenStageHasBattle() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)

        appState.battle.setMusicPreview(for: stage)

        XCTAssertEqual(appState.battle.preview?.stageID, stage.id)
        XCTAssertEqual(appState.battle.preview?.enemyID, "skeleton")
    }

    func testPauseForOverlayRestoresPreviousPauseStateWhenOverlayDismissed() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = false

        appState.battle.pauseForOverlay()
        XCTAssertTrue(appState.battle.isPaused)

        appState.battle.restorePauseAfterOverlay()
        XCTAssertFalse(appState.battle.isPaused)
    }

    func testRestartBattleRefreshesProgressionFromRosterWhenRosterUpdated() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        XCTAssertEqual(appState.battle.activeBattle?.hero.progression.currentXP, 0)

        var updatedRoster = appState.roster.current
        updatedRoster.grantExperience(25, to: appState.roster.activeHero)
        appState.roster.current = updatedRoster
        appState.restartActiveBattle()

        XCTAssertEqual(appState.battle.activeBattle?.hero.progression.currentXP, 25)
    }

    func testPresentCombatantDetailWithoutActiveBattleDoesNotPauseSession() throws {
        let appState = makeAppState()
        let enemy = try XCTUnwrap(GameContent.enemy(matching: "skeleton")?.combatant)

        appState.battle.presentCombatantDetail(CombatantCardDetail(combatant: enemy))

        XCTAssertFalse(appState.battle.isPaused)
        _ = try XCTUnwrap(appState.battle.overlayCombatantDetail)
    }

    func testEndBattleClearsSessionStateWhenBattleEnds() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = true
        appState.battle.preview = BattleMusicPreview(stageID: stage.id, enemyID: "skeleton")

        appState.battle.endBattle()

        XCTAssertNil(appState.battle.activeBattle)
        XCTAssertFalse(appState.battle.isPaused)
        XCTAssertNil(appState.battle.preview)
        XCTAssertNil(appState.battle.overlayCombatantDetail)
    }

    func testStartBattleReturnsMessageWhenEnemyMissing() {
        let appState = makeAppState()
        let brokenStage = Stage(
            id: "test-missing-enemy",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            flavorText: "",
            encounter: .battle(enemyID: "missing-enemy"),
            rewards: .empty
        )

        let message = appState.startBattle(for: brokenStage)

        XCTAssertEqual(message?.title, "Encounter Missing")
        XCTAssertNil(appState.battle.activeBattle)
    }

    func testRestartBattleRebuildsActiveConfigurationWhenBattleActive() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        let original = try XCTUnwrap(appState.battle.activeBattle)

        appState.restartActiveBattle()

        let restarted = try XCTUnwrap(appState.battle.activeBattle)
        XCTAssertEqual(restarted.stageID, original.stageID)
        XCTAssertEqual(restarted.hero.combatant.id, original.hero.combatant.id)
        XCTAssertNotEqual(restarted.id, original.id)
    }

    func testPresentCombatantDetailPausesBattleAndSetsOverlayWhenBattleActive() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = false
        let detail = CombatantCardDetail(combatant: appState.roster.activeHero)

        appState.battle.presentCombatantDetail(detail)

        XCTAssertTrue(appState.battle.isPaused)
        _ = try XCTUnwrap(appState.battle.overlayCombatantDetail)
    }

    func testRestorePauseAfterOverlayPreservesPriorPausedStateWhenAlreadyPaused() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = true
        appState.battle.presentCombatantDetail(CombatantCardDetail(combatant: appState.roster.activeHero))

        appState.battle.restorePauseAfterOverlay()

        XCTAssertTrue(appState.battle.isPaused)
    }

    func testSetMusicPreviewClearsWhenBattleActive() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        appState.battle.setMusicPreview(for: stage)
        _ = appState.startBattle(for: stage)

        appState.battle.setMusicPreview(for: stage)

        XCTAssertNil(appState.battle.preview)
    }

    func testSetMusicPreviewClearsForNonBattleStage() throws {
        let appState = makeAppState()
        let shopStage = try XCTUnwrap(GameContent.chapters[0].stages.first { $0.encounter == .shop })

        appState.battle.setMusicPreview(for: shopStage)

        XCTAssertNil(appState.battle.preview)
    }

    func testAdvanceAutoTickShowsVictorySummaryWhenEnemyDefeated() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let session = BattleSession()
        session.activeBattle = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceAutoTick(journey: .initial, homestead: .freshStart)
        }

        XCTAssertTrue(session.isShowingVictory)
        _ = try XCTUnwrap(session.victorySummary)
        XCTAssertFalse(session.isShowingDefeat)
    }

    func testAdvanceAutoTickCompletesImmediatelyWhenStageRewardsAlreadyClaimed() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        var journey = JourneyProgressState.initial
        journey.markRewardsClaimed(for: stage)
        let session = BattleSession()
        session.activeBattle = ActiveBattleConfigurationTestSupport.make(
            stageID: stage.id,
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy
        )

        var earnedGold: Int?
        while session.outcome == nil {
            earnedGold = session.advanceAutoTick(journey: journey, homestead: .freshStart)
            if earnedGold != nil { break }
        }

        XCTAssertEqual(earnedGold, session.state?.earnedGold ?? 0)
        XCTAssertFalse(session.isShowingVictory)
        XCTAssertNil(session.victorySummary)
    }

    func testAdvanceAutoTickDoesNotAdvanceWhenBattlePaused() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        let session = BattleSession()
        session.activeBattle = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)
        session.isPaused = true
        let tickBefore = session.state?.tickCount ?? 0

        _ = session.advanceAutoTick(journey: .initial, homestead: .freshStart)

        XCTAssertEqual(session.state?.tickCount, tickBefore)
    }

    func testClearOutcomePresentationResetsVictoryAndDefeatFlagsWhenCleared() {
        let session = BattleSession()
        session.isShowingVictory = true
        session.isShowingDefeat = true
        session.victorySummary = BattleVictorySummary(
            stageGold: 1,
            battleGold: 2,
            experience: 3,
            petExperience: 4,
            heroName: "Hero",
            petName: "Pet",
            itemNames: [],
            materialRewards: [],
            heroProgressionBefore: .initial,
            heroProgressionAfter: .initial,
            petProgressionBefore: .initial,
            petProgressionAfter: .initial
        )

        session.clearOutcomePresentation()

        XCTAssertFalse(session.isShowingVictory)
        XCTAssertFalse(session.isShowingDefeat)
        XCTAssertNil(session.victorySummary)
    }

    func testAdvanceOneStepAppendsNonMilestoneEventsWhenStepAdvances() {
        let session = makeConfiguredSession()

        _ = session.advanceOneStep()

        XCTAssertFalse(session.activeFeedbackEvents.isEmpty)
        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    func testAdvanceOneStepExcludesMilestonesWhenBattleEnds() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let session = makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while !(session.state?.isBattleOver ?? true) {
            _ = session.advanceOneStep()
        }

        XCTAssertTrue(session.state?.isPartyDefeated == true)
        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    func testResetClearsFeedbackAndRebuildsStateWhenResetCalled() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(
            id: "pet",
            role: .pet,
            actionIntervalTicks: 100,
            abilities: []
        )
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        let session = makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        _ = session.advanceOneStep()
        _ = session.advanceOneStep()
        XCTAssertFalse(session.activeFeedbackEvents.isEmpty)
        XCTAssertLessThan(session.state?.health(of: session.state?.enemy ?? enemy) ?? 0, 100)

        session.activeBattle = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(session.activeFeedbackEvents.isEmpty)
        XCTAssertEqual(session.state?.health(of: session.state?.enemy ?? enemy), 100)
        XCTAssertEqual(session.state?.health(of: session.state?.hero ?? hero), hero.maxHealth)
    }

    func testRemoveFeedbackEventRemovesByIDWhenMatchingID() throws {
        let session = makeConfiguredSession()

        _ = session.advanceOneStep()
        let eventID = try XCTUnwrap(session.activeFeedbackEvents.first?.id)

        session.removeFeedbackEvent(eventID)

        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
    }

    func testPruneExpiredFeedbackRemovesEventsWhenPastDisplayDuration() throws {
        let session = makeConfiguredSession()

        _ = session.advanceOneStep()
        let eventID = try XCTUnwrap(session.activeFeedbackEvents.first?.id)
        let now = Date()

        session.pruneExpiredFeedback(at: now)
        XCTAssertTrue(session.activeFeedbackEvents.contains { $0.id == eventID })

        session.pruneExpiredFeedback(
            at: now.addingTimeInterval(CombatFeedbackTiming.displayDuration + 0.1)
        )
        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
    }

    func testOutcomeReportsOngoingWhenBattleInProgress() {
        let session = makeConfiguredSession()

        _ = session.advanceOneStep()

        XCTAssertNil(session.outcome)
    }

    func testOutcomeReportsVictoryWhenEnemyDefeated() {
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let session = makeConfiguredSession(enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        XCTAssertEqual(session.outcome, .victory)
    }

    func testOutcomeReportsDefeatWhenPartyDefeated() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let session = makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        XCTAssertEqual(session.outcome, .defeat)
    }

    func testOutcomeReportsVictoryWhenFaustianBargainDefeatsEnemyAndPetSurvives() {
        let hero = Combatant(
            id: "warlock",
            name: "Warlock",
            role: .hero,
            maxHealth: 3,
            actionIntervalTicks: 1,
            abilities: [.faustianBargain]
        )
        let pet = Combatant(
            id: "pet",
            name: "Pet",
            role: .pet,
            maxHealth: 20,
            actionIntervalTicks: 100,
            abilities: []
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 6,
            actionIntervalTicks: 100,
            abilities: []
        )
        let session = makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        XCTAssertEqual(session.outcome, .victory)
        XCTAssertFalse(session.state?.isPartyDefeated ?? true)
        XCTAssertTrue(session.state?.isEnemyDefeated ?? false)
    }

    func testOutcomeReportsVictoryWhenEnemyAndPartyDefeatedTogether() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 0)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 0)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 0)
        let session = makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(session.state?.isPartyDefeated ?? false)
        XCTAssertTrue(session.state?.isEnemyDefeated ?? false)
        XCTAssertEqual(session.outcome, .victory)
    }

    func testMakeVictorySummaryIncludesStageAndBattleRewardsWhenVictory() throws {
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        var rosterState = PlayerRosterState.freshStart
        rosterState.progressions[hero.id] = CombatantProgression(level: 2, currentXP: 10, requiredXP: 155)
        rosterState.progressions[pet.id] = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let configuration = ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-1",
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy,
            enemyEncounterLevel: 2,
            roster: rosterState,
            stageReward: StageReward(gold: 12, itemTemplateIDs: ["shortsword-basic"])
        )
        let session = BattleSession()
        session.activeBattle = configuration

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: XCTUnwrap(session.state),
            homestead: .freshStart
        )
        let expectedHeroXP = ExperienceScaling.battleAward(playerLevel: 2, enemyLevel: 2)
        let expectedPetXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 2)

        XCTAssertEqual(summary.stageGold, 12)
        XCTAssertEqual(summary.experience, expectedHeroXP)
        XCTAssertEqual(summary.heroName, hero.name)
        XCTAssertEqual(summary.petName, pet.name)
        XCTAssertEqual(summary.itemNames, ["Shortsword"])
        XCTAssertEqual(summary.heroProgressionBefore.level, 2)
        XCTAssertEqual(summary.heroProgressionAfter.currentXP, 10 + expectedHeroXP)
        XCTAssertEqual(summary.petProgressionAfter.currentXP, expectedPetXP)
    }

    func testMakeVictorySummaryScalesExperienceWhenEncounterLevelDiffers() throws {
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        var rosterState = PlayerRosterState.freshStart
        rosterState.progressions[hero.id] = CombatantProgression(level: 15, currentXP: 0, requiredXP: 100)
        rosterState.progressions[pet.id] = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy,
            enemyEncounterLevel: 1,
            roster: rosterState,
            stageReward: StageReward(gold: 0, itemTemplateIDs: [])
        )
        let session = BattleSession()
        session.activeBattle = configuration

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: XCTUnwrap(session.state),
            homestead: .freshStart
        )
        let expectedPetXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 1)

        XCTAssertEqual(summary.experience, 0)
        XCTAssertEqual(summary.petExperience, expectedPetXP)
        XCTAssertEqual(summary.hasExperienceAwards, true)
        XCTAssertEqual(summary.petProgressionAfter.currentXP, expectedPetXP)
    }

    func testMakeVictorySummaryIncludesBattleGoldWhenRewardsGranted() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let configuration = ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-1",
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy,
            stageReward: StageReward(gold: 12, itemTemplateIDs: [])
        )
        let session = BattleSession()
        session.activeBattle = configuration

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: XCTUnwrap(session.state),
            homestead: .freshStart
        )

        XCTAssertEqual(summary.stageGold, 12)
        XCTAssertGreaterThanOrEqual(summary.battleGold, 0)
        XCTAssertEqual(summary.totalGold, summary.stageGold + summary.battleGold)
    }

    func testMakeVictorySummaryAppliesHomesteadBonusesWhenBonusesActive() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy,
            stageReward: StageReward(
                gold: 0,
                itemTemplateIDs: [],
                materialRewards: [ResourceAmount(.wood, 8), ResourceAmount(.stone, 3)]
            )
        )
        let session = BattleSession()
        session.activeBattle = configuration
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 3])

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: XCTUnwrap(session.state),
            homestead: homestead
        )

        XCTAssertEqual(summary.materialRewards.first { $0.resource == .wood }?.quantity, 9)
        XCTAssertEqual(summary.materialRewards.first { $0.resource == .stone }?.quantity, 4)
    }

    func testResetPreservesEnemyModifiersWhenBattleReset() throws {
        let enemy = try XCTUnwrap(GameContent.enemy(matching: "skeleton"))
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy.combatant
        )
        let session = BattleSession()
        session.activeBattle = configuration

        session.activeBattle = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 1,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy.combatant
        )

        XCTAssertGreaterThan(
            session.state?.modifiers(for: enemy.combatant.id).controlResistancePercent ?? 0,
            0
        )
    }

    private func makeConfiguredSession(
        rngSeed: UInt64 = 0,
        hero: Combatant? = nil,
        pet: Combatant? = nil,
        enemy: Combatant? = nil
    ) -> BattleSession {
        let resolvedHero = hero ?? CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let resolvedPet = pet ?? CombatantFixtures.combatant(
            id: "pet",
            role: .pet,
            actionIntervalTicks: 100,
            abilities: []
        )
        let resolvedEnemy = enemy ?? CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        let session = BattleSession()
        session.activeBattle = ActiveBattleConfigurationTestSupport.make(
            rngSeed: rngSeed,
            hero: resolvedHero,
            pet: resolvedPet,
            enemy: resolvedEnemy
        )
        return session
    }

    private func makeAppState() -> AppState {
        let suiteName = "BattleSessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppState(
            environment: AppEnvironment.parse(arguments: [], environment: [:]),
            playerSave: SaveTestSupport.makeSaveStore(directoryURL: directoryURL),
            userDefaults: defaults
        )
    }
}

// swiftlint:enable file_length type_body_length
