import TrinketContent
import TrinketPersistence
import XCTest
@testable import BattleEngine
@testable import Trinket

@MainActor
final class AppStateBattleTickLoopTests: AppTestCase {

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

    func testBattleTickLoopStopsWhileInBackground() async throws {
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
        _ = try XCTUnwrap(appState.battleTickTask)

        appState.reconcileShellState(.scenePhaseChanged, scenePhase: .background)

        XCTAssertNil(appState.battleTickTask)

        let tickCountAfterBackground = try XCTUnwrap(appState.battle.state?.tickCount)
        try await assertTickCountRemainsStable(tickCountAfterBackground, for: appState)
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
        try await assertTickCountRemainsStable(tickCount, for: appState)
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

    private func assertTickCountRemainsStable(
        _ expected: Int,
        for appState: AppState,
        duration: Duration = .milliseconds(200),
        pollInterval: Duration = .milliseconds(10)
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: duration)
        while clock.now < deadline {
            XCTAssertEqual(appState.battle.state?.tickCount, expected)
            try await clock.sleep(for: pollInterval)
        }
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
