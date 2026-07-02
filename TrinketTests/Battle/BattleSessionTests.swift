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

    private func makeAppState() -> AppState {
        AppState(
            environment: AppEnvironment.parse(arguments: [], environment: [:]),
            sync: sync,
            fileStore: PlayerSaveFileStore(directoryURL: directoryURL)
        )
    }
}
