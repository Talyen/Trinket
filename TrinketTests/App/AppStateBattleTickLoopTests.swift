import Testing
import TrinketContent
import TrinketPersistence
@testable import BattleEngine
@testable import Trinket

@MainActor
final class AppStateBattleTickLoopTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func battleTickIntervalUsesInjectedEnvironment() throws {
        let appState = try context.makeAppState(arguments: ["-battle-tick-interval", "0.15"])
        #expect(appState.battleTickInterval == .seconds(0.15))
    }

    @Test func canAdvanceBattleTicksRequiresActivePlayTabAndUnpausedBattle() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        appState.shellScenePhase = .active
        appState.selectedTab = .play
        appState.battle.isPaused = false

        #expect(appState.canAdvanceBattleTicks)

        appState.battle.isPaused = true
        #expect(!(appState.canAdvanceBattleTicks))

        appState.battle.isPaused = false
        appState.selectedTab = .collection
        #expect(!(appState.canAdvanceBattleTicks))

        appState.selectedTab = .play
        appState.shellScenePhase = .background
        #expect(!(appState.canAdvanceBattleTicks))
    }

    @Test func battleTickLoopAdvancesSimulationWhenEligible() async throws {
        let appState = try context.makeAppState(arguments: ["-battle-tick-interval", "0.01"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        appState.shellScenePhase = .active
        appState.selectedTab = .play
        appState.battle.isPaused = false
        appState.syncBattleTickLoop()

        let initialTickCount = try #require(appState.battle.state?.tickCount)
        try await waitUntil {
            (appState.battle.state?.tickCount ?? initialTickCount) > initialTickCount
        }

        #expect(try #require(appState.battle.state?.tickCount) > initialTickCount)
    }

    @Test func battleTickLoopStopsWhileInBackground() async throws {
        let appState = try context.makeAppState(arguments: ["-battle-tick-interval", "0.01"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        appState.shellScenePhase = .active
        appState.selectedTab = .play
        appState.battle.isPaused = false
        appState.syncBattleTickLoop()

        let initialTickCount = try #require(appState.battle.state?.tickCount)
        try await waitUntil {
            (appState.battle.state?.tickCount ?? initialTickCount) > initialTickCount
        }
        _ = try #require(appState.battleTickTask)

        appState.reconcileShellState(.scenePhaseChanged, scenePhase: .background)

        #expect(appState.battleTickTask == nil)

        let tickCountAfterBackground = try #require(appState.battle.state?.tickCount)
        try await assertTickCountRemainsStable(tickCountAfterBackground, for: appState)
    }

    @Test func battleTickLoopDoesNotAdvanceWhilePaused() async throws {
        let appState = try context.makeAppState(arguments: ["-battle-tick-interval", "0.01"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        appState.shellScenePhase = .active
        appState.selectedTab = .play
        appState.battle.isPaused = true
        appState.syncBattleTickLoop()

        let tickCount = try #require(appState.battle.state?.tickCount)
        try await assertTickCountRemainsStable(tickCount, for: appState)
    }

    @Test func trimMemoryFootprintReleasesBattleLogProjection() throws {
        let session = BattleSession()
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: GameContent.heroes[0],
            pet: GameContent.pets[0],
            enemy: GameContent.enemy(matching: "skeleton")?.combatant
        )
        _ = session.advanceOneStep()
        session.syncLogForDisplay()
        #expect(!(session.state?.log.isEmpty ?? true))

        session.trimMemoryFootprint(releaseBattleLog: true)

        #expect(session.state?.log.isEmpty ?? false)
        #expect(!(session.state?.events.isEmpty ?? true))
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
            #expect(appState.battle.state?.tickCount == expected)
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
        Issue.record("Timed out waiting for condition")
    }
}
