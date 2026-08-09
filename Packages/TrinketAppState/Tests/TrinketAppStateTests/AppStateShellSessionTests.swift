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

    @Test func freshStateLandsOnPlayAfterTabChange() throws {
        let state = try makeState()
        state.selectedTab = .options

        #expect(try makeState().selectedTab == .play)
    }
}
