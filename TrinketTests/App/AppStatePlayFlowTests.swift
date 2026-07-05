import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

@MainActor
final class AppStatePlayFlowTests: XCTestCase {
    private var directoryURL: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "AppStatePlayFlowTests")
        suiteName = "AppStatePlayFlowTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    func testCompleteActiveBattleWithStageCompletesJourneyAndEndsBattle() throws {
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.battle.startBattle(
            stage: stage,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            roster: state.roster,
            inventory: state.inventory
        )
        let configuration = try XCTUnwrap(state.battle.activeBattle)
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
        XCTAssertTrue(state.journey.current.completedStageIDs.contains(stage.id))
        XCTAssertGreaterThan(state.roster.current.gold, initialGold + 4)
    }

    func testCompleteActiveBattleIsIdempotentWhenContinueTappedTwice() throws {
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.battle.startBattle(
            stage: stage,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            roster: state.roster,
            inventory: state.inventory
        )
        let configuration = try XCTUnwrap(state.battle.activeBattle)
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 5)
        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
        XCTAssertEqual(state.roster.current.gold, initialGold + 5 + stage.rewards.gold)
    }

    func testCompleteActiveBattleWithoutStageGrantsGoldOnly() throws {
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)
        let configuration = ActiveBattleConfiguration.make(
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
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)
        let configuration = ActiveBattleConfiguration.make(
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
        let fileStore = PlayerSaveFileStore(directoryURL: directoryURL)
        let playerSave = PlayerSaveStore(
            fileStore: fileStore,
            immediatePersistRetryCount: 1,
            immediatePersistRetryDelayNanoseconds: 0,
            persistDebounceNanoseconds: 0
        )
        let state = AppTestSupport.makeAppState(
            playerSave: playerSave,
            fileStore: fileStore,
            directoryURL: directoryURL
        )
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.battle.startBattle(
            stage: stage,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            roster: state.roster,
            inventory: state.inventory
        )
        let configuration = try XCTUnwrap(state.battle.activeBattle)

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o555))],
            ofItemAtPath: directoryURL.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o755))],
                ofItemAtPath: directoryURL.path
            )
        }

        state.completeActiveBattle(configuration, battleEarnedGold: 0)

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
        XCTAssertTrue(state.playerSave.hasPendingPersist)
    }

    func testMapScrollFocusIDReturnsActiveStageWhenInProgress() {
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)

        XCTAssertEqual(state.mapScrollFocusID(for: .initial), "chapter-1-stage-1")
    }

    func testMapScrollFocusIDReturnsChapterGateWhenChapterComplete() {
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)
        var progress = JourneyProgressState.initial
        for stage in GameContent.chapters[0].stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        XCTAssertNil(progress.activeStageID)
        XCTAssertEqual(
            state.mapScrollFocusID(for: progress),
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

    func testResetGameplayProgressClearsBattleAndJourneyScroll() throws {
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.battle.startBattle(
            stage: stage,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            roster: state.roster,
            inventory: state.inventory
        )
        state.journey.requestMapScroll(to: "chapter-1-stage-2")
        _ = state.completeStage(stage, hero: state.roster.activeHero, pet: state.roster.activePet)

        state.resetGameplayProgress()

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.journey.mapScrollRequest)
        XCTAssertEqual(state.selectedTab, .play)
        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-1")
        XCTAssertTrue(state.journey.current.completedStageIDs.isEmpty)
    }

    func testCompleteStageReturnsScrollFocusWithoutPersistingWhenSaveFails() throws {
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        let hero = state.roster.activeHero
        let pet = state.roster.activePet

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directoryURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directoryURL.path)
        }

        let scrollTarget = state.completeStage(stage, hero: hero, pet: pet)

        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-2")
        XCTAssertTrue(state.journey.current.completedStageIDs.contains(stage.id))
        XCTAssertTrue(state.playerSave.hasPendingPersist)
        XCTAssertEqual(scrollTarget, "chapter-1-stage-2")
    }

    // MARK: - Session state restoration

    func testSessionTabRestored() throws {
        defaults.set(AppTab.homestead.rawValue, forKey: "session.selectedTab")

        let state = AppTestSupport.makeAppState(
            directoryURL: directoryURL,
            userDefaults: defaults
        )

        XCTAssertEqual(state.selectedTab, .homestead)
    }

    func testSessionTabOverriddenByEnv() throws {
        defaults.set(AppTab.homestead.rawValue, forKey: "session.selectedTab")

        let state = AppTestSupport.makeAppState(
            arguments: ["-selectedTab", "options"],
            directoryURL: directoryURL,
            userDefaults: defaults
        )

        XCTAssertEqual(state.selectedTab, .options)
    }

    func testSessionTabDefaultWhenNoSavedState() throws {
        let state = AppTestSupport.makeAppState(
            directoryURL: directoryURL,
            userDefaults: defaults
        )

        XCTAssertEqual(state.selectedTab, .play)
    }

    func testSessionBattleRestored() throws {
        defaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = AppTestSupport.makeAppState(
            directoryURL: directoryURL,
            userDefaults: defaults
        )

        XCTAssertNotNil(state.battle.activeBattle)
        XCTAssertEqual(state.battle.activeBattle?.stageID, "chapter-1-stage-1")
        XCTAssertEqual(state.selectedTab, .play)
    }

    func testSessionBattleNotRestoredWhenRewardsAlreadyClaimed() throws {
        defaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = AppTestSupport.makeAppState(
            arguments: ["-completed-stages", "chapter-1-stage-1"],
            directoryURL: directoryURL,
            userDefaults: defaults
        )

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.sessionState.activeBattleStageID)
    }

    func testCompleteStageUpdatesSessionMapScrollTarget() throws {
        let state = AppTestSupport.makeAppState(
            directoryURL: directoryURL,
            userDefaults: defaults
        )
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        defaults.set(stage.id, forKey: "session.mapScrollStageID")

        _ = state.completeStage(stage, hero: state.roster.activeHero, pet: state.roster.activePet)

        XCTAssertEqual(state.sessionState.mapScrollStageID, "chapter-1-stage-2")
    }

    func testShouldRestoreMapScrollIgnoresCompletedStage() {
        var journey = JourneyProgressState.initial
        journey.complete(GameContent.chapters[0].stages[0], in: GameContent.chapters)

        XCTAssertFalse(AppState.shouldRestoreMapScroll("chapter-1-stage-1", journey: journey))
        XCTAssertTrue(AppState.shouldRestoreMapScroll("chapter-1-stage-2", journey: journey))
    }

    func testSessionBattleNotRestoredWhenLaunchScreenBattle() throws {
        defaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = AppTestSupport.makeAppState(
            arguments: ["-launch-screen", "battle"],
            directoryURL: directoryURL,
            userDefaults: defaults
        )

        // launch-screen battle uses the hardcoded stage, not the session one
        XCTAssertNotNil(state.battle.activeBattle)
        XCTAssertEqual(state.battle.activeBattle?.stageID, "chapter-1-stage-1")
    }

    func testSessionStaleStageIDIgnored() throws {
        defaults.set("nonexistent-stage", forKey: "session.activeBattleStageID")

        let state = AppTestSupport.makeAppState(
            directoryURL: directoryURL,
            userDefaults: defaults
        )

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.sessionState.activeBattleStageID)
    }

    func testSessionBattleClearedOnEndBattle() throws {
        defaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = AppTestSupport.makeAppState(
            directoryURL: directoryURL,
            userDefaults: defaults
        )
        XCTAssertNotNil(state.battle.activeBattle)

        state.battle.endBattle()

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.sessionState.activeBattleStageID)
    }

    func testResetGameplayProgressClearsSessionBattleState() throws {
        let state = AppTestSupport.makeAppState(
            directoryURL: directoryURL,
            userDefaults: defaults
        )
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = state.battle.startBattle(
            stage: stage,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            roster: state.roster,
            inventory: state.inventory
        )
        state.sessionState.mapScrollStageID = "chapter-1-stage-2"

        state.resetGameplayProgress()

        XCTAssertNil(state.battle.activeBattle)
        XCTAssertNil(state.sessionState.activeBattleStageID)
        XCTAssertNil(state.sessionState.mapScrollStageID)
    }

    func testSessionBattleStageIDSetOnStartBattle() throws {
        let state = AppTestSupport.makeAppState(
            directoryURL: directoryURL,
            userDefaults: defaults
        )
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        XCTAssertNil(state.sessionState.activeBattleStageID)

        _ = state.battle.startBattle(
            stage: stage,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            roster: state.roster,
            inventory: state.inventory
        )

        XCTAssertEqual(state.sessionState.activeBattleStageID, "chapter-1-stage-1")
    }
}
