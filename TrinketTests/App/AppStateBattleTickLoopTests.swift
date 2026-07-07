import TrinketContent
import TrinketPersistence
import XCTest
@testable import BattleEngine
@testable import Trinket

@MainActor
final class AppStateBattleTickLoopTests: XCTestCase {
    private var directoryURL: URL!
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "AppStateBattleTickLoopTests.\(UUID().uuidString)"
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directoryURL)
        try await super.tearDown()
    }

    func testCanAdvanceBattleTicksRequiresActivePlayTabAndUnpausedBattle() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        appState.shellScenePhase = .active
        appState.selectedTab = .play
        appState.battle.isPaused = false

        XCTAssertTrue(appState.canAdvanceBattleTicks)

        appState.battle.isPaused = true
        XCTAssertFalse(appState.canAdvanceBattleTicks)

        appState.battle.isPaused = false
        appState.selectedTab = .collection
        XCTAssertFalse(appState.canAdvanceBattleTicks)

        appState.selectedTab = .play
        appState.shellScenePhase = .background
        XCTAssertFalse(appState.canAdvanceBattleTicks)
    }

    func testBattleTickLoopAdvancesSimulationWhenEligible() async throws {
        let appState = makeAppState(arguments: ["-battle-tick-interval", "0.01"])
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        appState.shellScenePhase = .active
        appState.selectedTab = .play
        appState.battle.isPaused = false
        appState.syncBattleTickLoop()

        let initialTickCount = try XCTUnwrap(appState.battle.state?.tickCount)
        try await waitUntil {
            (appState.battle.state?.tickCount ?? initialTickCount) > initialTickCount
        }

        XCTAssertGreaterThan(try XCTUnwrap(appState.battle.state?.tickCount), initialTickCount)
    }

    func testBattleTickLoopDoesNotAdvanceWhilePaused() async throws {
        let appState = makeAppState(arguments: ["-battle-tick-interval", "0.01"])
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        appState.shellScenePhase = .active
        appState.selectedTab = .play
        appState.battle.isPaused = true
        appState.syncBattleTickLoop()

        let tickCount = try XCTUnwrap(appState.battle.state?.tickCount)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(appState.battle.state?.tickCount, tickCount)
    }

    func testTrimMemoryFootprintReleasesBattleLogProjection() throws {
        let session = BattleSession()
        session.activeBattle = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: GameContent.heroes[0],
            pet: GameContent.pets[0],
            enemy: GameContent.enemy(matching: "skeleton")?.combatant
        )
        _ = session.advanceOneStep()
        session.syncLogForDisplay()
        XCTAssertFalse(session.state?.log.isEmpty ?? true)

        session.trimMemoryFootprint(releaseBattleLog: true)

        XCTAssertTrue(session.state?.log.isEmpty ?? false)
        XCTAssertFalse(session.state?.events.isEmpty ?? true)
    }

    private func makeAppState(arguments: [String] = []) -> AppState {
        AppState(
            environment: AppEnvironment.parse(
                arguments: arguments,
                environment: ["XCTestConfigurationFilePath": "/tmp/xctest"]
            ),
            playerSave: PlayerSaveStore(
                storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
                disableCloudSync: true
            ),
            userDefaults: userDefaults
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        pollInterval: Duration = .milliseconds(10),
        condition: @escaping () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() { return }
            try await clock.sleep(for: pollInterval)
        }
        XCTFail("Timed out waiting for condition")
    }
}
