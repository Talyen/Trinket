import XCTest
@testable import Trinket

@MainActor
final class AppStatePlayFlowTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "AppStatePlayFlowTests")
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
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

    func testCompleteActiveBattleWithoutStageGrantsGoldOnly() throws {
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)
        let configuration = ActiveBattleConfiguration.make(
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
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            enemy: enemy
        )
        state.battle.activeBattle = configuration
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 0)

        XCTAssertEqual(state.roster.current.gold, initialGold)
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
        XCTAssertEqual(state.journey.current.activeStageID, "chapter-1-stage-1")
        XCTAssertTrue(state.journey.current.completedStageIDs.isEmpty)
    }

    func testCompleteStageReturnsScrollFocusWithoutPersistingWhenSaveFails() throws {
        let state = AppTestSupport.makeAppState(directoryURL: directoryURL)
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        let hero = state.roster.activeHero
        let pet = state.roster.activePet
        let journeyBefore = state.journey.current

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directoryURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directoryURL.path)
        }

        let scrollTarget = state.completeStage(stage, hero: hero, pet: pet)

        XCTAssertEqual(state.journey.current, journeyBefore)
        XCTAssertEqual(scrollTarget, state.mapScrollFocusID(for: journeyBefore))
    }
}
