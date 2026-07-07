import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

@MainActor
final class AppStatePlayFlowTests: AppTestCase {

    func testCompleteActiveBattleWithStageCompletesJourneyAndEndsBattle() throws {
        let state = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try XCTUnwrap(state.battle.activeBattle)
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
        XCTAssertTrue(state.journey.current.completedStageIDs.contains(stage.id))
        XCTAssertGreaterThan(state.roster.current.gold, initialGold + 4)
    }

    func testCompleteActiveBattleIsIdempotentWhenContinueTappedTwice() throws {
        let state = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try XCTUnwrap(state.battle.activeBattle)
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 5)
        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
        XCTAssertEqual(state.roster.current.gold, initialGold + 5 + stage.rewards.gold)
    }

    func testCompleteActiveBattleWithoutStageGrantsGoldOnly() throws {
        let state = makeAppState()
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            enemy: enemy
        )
        state.battle.activeBattle = configuration
        let journeyBefore = state.journey.current
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 10)

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertEqual(state.journey.current, journeyBefore)
        XCTAssertEqual(state.roster.current.gold, initialGold + 10)
    }

    func testCompleteActiveBattleWithoutStageIgnoresZeroGold() throws {
        let state = makeAppState()
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            enemy: enemy
        )
        state.battle.activeBattle = configuration
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 0)

        XCTAssertEqual(state.roster.current.gold, initialGold)
    }

    func testCompleteActiveBattleAdvancesJourneyWhenPersistFails() throws {
        let playerSave = SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        let state = makeAppState(playerSave: playerSave)
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try XCTUnwrap(state.battle.activeBattle)

        state.completeActiveBattle(configuration, battleEarnedGold: 0)

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
    }

    func testMapScrollFocusIDReturnsActiveStageWhenInProgress() {
        let state = makeAppState()

        XCTAssertEqual(JourneyMapPresentation.scrollFocusID(for: .initial), "chapter-1-stage-1")
    }

    func testMapScrollFocusIDReturnsChapterGateWhenChapterComplete() {
        let state = makeAppState()
        var progress = JourneyProgressState.initial
        for stage in GameContent.chapters[0].stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        XCTAssertNil(progress.activeStageID)
        XCTAssertEqual(
            JourneyMapPresentation.scrollFocusID(for: progress),
            StageMapID.chapterGate(
                for: Chapter(
                    id: StageMapID.placeholderGate(afterChapterNumber: 2),
                    number: 2,
                    title: "",
                    theme: GameContent.chapters[0].theme,
                    stages: []
                )
            )
        )
    }

    func testResetGameplayProgressClearsBattleAndMapScroll() throws {
        let state = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.noteMapScrollFocus("chapter-1-stage-2")
        _ = state.completeStage(stage, hero: state.roster.activeHero, pet: state.roster.activePet)

        state.resetGameplayProgress()

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.mapScrollStageID)
        XCTAssertEqual(state.selectedTab, .play)
        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-1")
        XCTAssertTrue(state.journey.current.completedStageIDs.isEmpty)
    }

    func testCompleteStageReturnsScrollFocusWithoutPersistingWhenSaveFails() throws {
        let state = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        let hero = state.roster.activeHero
        let pet = state.roster.activePet

        let scrollTarget = state.completeStage(stage, hero: hero, pet: pet)

        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
        XCTAssertTrue(state.journey.current.completedStageIDs.contains(stage.id))
        XCTAssertEqual(scrollTarget, "chapter-1-stage-2")
    }

    // MARK: - Session state restoration

    func testSessionTabRestored() {
        userDefaults.set(AppTab.homestead.rawValue, forKey: "session.selectedTab")

        let state = makeAppState()

        XCTAssertEqual(state.selectedTab, .homestead)
    }

    func testSessionTabOverriddenByEnv() {
        userDefaults.set(AppTab.homestead.rawValue, forKey: "session.selectedTab")

        let state = makeAppState(arguments: ["-selectedTab", "options"])

        XCTAssertEqual(state.selectedTab, .options)
    }

    func testSessionTabDefaultWhenNoSavedState() {
        let state = makeAppState()

        XCTAssertEqual(state.selectedTab, .play)
    }

    func testSessionBattleRestored() throws {
        userDefaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = makeAppState()

        let activeBattle = try XCTUnwrap(state.battle.activeBattle)
        XCTAssertEqual(activeBattle.stageID, "chapter-1-stage-1")
        XCTAssertEqual(state.selectedTab, .play)
    }

    func testSessionBattleNotRestoredWhenRewardsAlreadyClaimed() {
        userDefaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = makeAppState(arguments: ["-completed-stages", "chapter-1-stage-1"])

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.activeBattleStageID)
    }

    func testCompleteStageUpdatesSessionMapScrollTarget() throws {
        let state = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        userDefaults.set(stage.id, forKey: "session.mapScrollStageID")

        _ = state.completeStage(stage, hero: state.roster.activeHero, pet: state.roster.activePet)

        XCTAssertEqual(state.mapScrollStageID, "chapter-1-stage-2")
    }

    func testShouldRestoreMapScrollIgnoresCompletedStage() {
        var journey = JourneyProgressState.initial
        journey.complete(GameContent.chapters[0].stages[0], in: GameContent.chapters)

        XCTAssertFalse(AppState.shouldRestoreMapScroll("chapter-1-stage-1", journey: journey))
        XCTAssertTrue(AppState.shouldRestoreMapScroll("chapter-1-stage-2", journey: journey))
    }

    func testSessionBattleNotRestoredWhenLaunchScreenBattle() throws {
        userDefaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = makeAppState(arguments: ["-launch-screen", "battle"])

        // launch-screen battle uses the hardcoded stage, not the session one
        let activeBattle = try XCTUnwrap(state.battle.activeBattle)
        XCTAssertEqual(activeBattle.stageID, "chapter-1-stage-1")
    }

    func testSessionStaleStageIDIgnored() {
        userDefaults.set("nonexistent-stage", forKey: "session.activeBattleStageID")

        let state = makeAppState()

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.activeBattleStageID)
    }

    func testSessionBattleClearedOnEndBattle() throws {
        userDefaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = makeAppState()
        _ = try XCTUnwrap(state.battle.activeBattle)

        state.battle.endBattle()

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.activeBattleStageID)
    }

    func testResetGameplayProgressClearsSessionBattleState() throws {
        let state = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.mapScrollStageID = "chapter-1-stage-2"

        state.resetGameplayProgress()

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.activeBattleStageID)
        XCTAssertNil(state.mapScrollStageID)
    }

    func testSessionBattleStageIDSetOnStartBattle() throws {
        let state = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        XCTAssertNil(state.activeBattleStageID)

        _ = state.startBattle(for: stage)

        XCTAssertEqual(state.activeBattleStageID, "chapter-1-stage-1")
    }
}
