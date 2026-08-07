import Testing
import TrinketBattleFeature
import TrinketFeatureSupport
import TrinketPersistence
@testable import TrinketAppState

@MainActor
struct AppStateShellSessionTests {
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
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: ShellSession.legacySessionTabKey)

        let state = try makeState()

        // Shell session is never persisted; legacy UserDefaults keys are not migrated.
        #expect(state.selectedTab == .play)
        #expect(state.play.battle.activeBattle == nil)
        #expect(context.userDefaults.string(forKey: ShellSession.legacySessionTabKey) == AppTab.homestead.rawValue)
    }

    @Test func freshStateLandsOnPlayAfterTabChange() throws {
        let state = try makeState()
        state.selectedTab = .options

        #expect(try makeState().selectedTab == .play)
    }
}
