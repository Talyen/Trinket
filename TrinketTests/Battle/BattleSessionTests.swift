import XCTest
@testable import Trinket

@MainActor
final class BattleSessionTests: XCTestCase {
    private var directoryURL: URL!
    private let sync = LocalOnlyPlayerSaveSync()

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

    func testStartBattleConfiguresActiveBattle() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)

        let message = appState.battle.startBattle(
            stage: stage,
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            roster: appState.roster,
            inventory: appState.inventory
        )

        XCTAssertNil(message)
        XCTAssertNotNil(appState.battle.activeBattle)
        XCTAssertEqual(appState.battle.activeBattle?.stageID, stage.id)
        XCTAssertNil(appState.battle.preview)
    }

    func testSetMusicPreviewUsesBattleEncounter() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)

        appState.battle.setMusicPreview(for: stage)

        XCTAssertEqual(appState.battle.preview?.stageID, stage.id)
        XCTAssertEqual(appState.battle.preview?.enemyID, "skeleton")
    }

    func testPauseForOverlayRestoresPreviousPauseState() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.battle.startBattle(
            stage: stage,
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            roster: appState.roster,
            inventory: appState.inventory
        )
        appState.battle.isPaused = false

        appState.battle.pauseForOverlay()
        XCTAssertTrue(appState.battle.isPaused)

        appState.battle.restorePauseAfterOverlay()
        XCTAssertFalse(appState.battle.isPaused)
    }

    func testEndBattleClearsSessionState() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.battle.startBattle(
            stage: stage,
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            roster: appState.roster,
            inventory: appState.inventory
        )
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

        let message = appState.battle.startBattle(
            stage: brokenStage,
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            roster: appState.roster,
            inventory: appState.inventory
        )

        XCTAssertEqual(message?.title, "Encounter Missing")
        XCTAssertNil(appState.battle.activeBattle)
    }

    func testRestartBattleRebuildsActiveConfiguration() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.battle.startBattle(
            stage: stage,
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            roster: appState.roster,
            inventory: appState.inventory
        )
        let original = try XCTUnwrap(appState.battle.activeBattle)

        appState.battle.restartBattle(using: appState.roster)

        let restarted = try XCTUnwrap(appState.battle.activeBattle)
        XCTAssertEqual(restarted.stageID, original.stageID)
        XCTAssertEqual(restarted.hero.id, original.hero.id)
        XCTAssertNotEqual(restarted.id, original.id)
    }

    func testPresentCombatantDetailPausesBattleAndSetsOverlay() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.battle.startBattle(
            stage: stage,
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            roster: appState.roster,
            inventory: appState.inventory
        )
        appState.battle.isPaused = false
        let detail = CombatantCardDetail.base(appState.roster.activeHero)

        appState.battle.presentCombatantDetail(detail)

        XCTAssertTrue(appState.battle.isPaused)
        XCTAssertNotNil(appState.battle.overlayCombatantDetail)
    }

    func testRestorePauseAfterOverlayPreservesPriorPausedState() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.battle.startBattle(
            stage: stage,
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            roster: appState.roster,
            inventory: appState.inventory
        )
        appState.battle.isPaused = true
        appState.battle.presentCombatantDetail(.base(appState.roster.activeHero))

        appState.battle.restorePauseAfterOverlay()

        XCTAssertTrue(appState.battle.isPaused)
        XCTAssertNil(appState.battle.pauseStateBeforeOverlay)
    }

    func testSetMusicPreviewClearsWhenBattleActive() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        appState.battle.setMusicPreview(for: stage)
        _ = appState.battle.startBattle(
            stage: stage,
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            roster: appState.roster,
            inventory: appState.inventory
        )

        appState.battle.setMusicPreview(for: stage)

        XCTAssertNil(appState.battle.preview)
    }

    func testSetMusicPreviewClearsForNonBattleStage() throws {
        let appState = makeAppState()
        let shopStage = try XCTUnwrap(GameContent.chapters[0].stages.first { $0.encounter == .shop })

        appState.battle.setMusicPreview(for: shopStage)

        XCTAssertNil(appState.battle.preview)
    }

    private func makeAppState() -> AppState {
        AppState(
            environment: AppEnvironment.parse(arguments: [], environment: [:]),
            sync: sync,
            fileStore: PlayerSaveFileStore(directoryURL: directoryURL)
        )
    }
}
