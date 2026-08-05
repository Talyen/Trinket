import Testing
import TrinketBattleFeature
import TrinketFeatureSupport
import TrinketPersistence
@testable import TrinketAppState

@MainActor
struct AppStateSessionPersistenceTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    private func makeState() throws -> AppState {
        try context.makeAppState()
    }

    @Test func defaultsWhenNoStoredValues() throws {
        let state = try makeState()

        #expect(state.selectedTab == .play)
    }

    @Test func ignoresLegacyShellUserDefaultsKeys() throws {
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: PlayerShellSessionStore.legacySessionTabKey)

        let state = try makeState()

        // Shell session is SwiftData-only; legacy UserDefaults keys are not migrated.
        #expect(state.selectedTab == .play)
        #expect(state.play.battle.activeBattle == nil)
        #expect(context.userDefaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == AppTab.homestead.rawValue)
    }

    @Test func selectedTabPersistsOnChangeButRelaunchLandsOnPlay() throws {
        let state = try makeState()
        state.selectedTab = .options

        #expect(try makeState().selectedTab == .play)
    }
}
