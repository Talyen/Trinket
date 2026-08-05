import Testing
import TrinketBattleFeature
import TrinketFeatureContracts
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
        #expect(state.play.mapScrollStageID == nil)
    }

    @Test func ignoresLegacyShellUserDefaultsKeys() throws {
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: PlayerShellSessionStore.legacySessionTabKey)
        context.userDefaults.set("chapter-1-stage-3", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)
        context.userDefaults.set("chapter-2-stage-1", forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey)

        let state = try makeState()

        // Shell session is SwiftData-only; legacy UserDefaults keys are not migrated.
        #expect(state.selectedTab == .play)
        #expect(state.play.battle.activeBattle == nil)
        #expect(state.play.mapScrollStageID == nil)
        #expect(context.userDefaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == AppTab.homestead.rawValue)
        #expect(context.userDefaults.string(forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey) == "chapter-2-stage-1")
    }

    @Test func selectedTabPersistsOnChangeButRelaunchLandsOnPlay() throws {
        let state = try makeState()
        state.selectedTab = .options

        #expect(try makeState().selectedTab == .play)
    }

    @Test func noteMapScrollFocusPersistsPublishesAndBumpsRevision() throws {
        let state = try makeState()

        state.play.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.play.mapScrollStageID == "chapter-1-stage-2")
        #expect(state.play.mapScrollFocus == MapScrollFocus(stageID: "chapter-1-stage-2", revision: 1))
        #expect(try makeState().play.mapScrollStageID == "chapter-1-stage-2")

        state.play.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.play.mapScrollFocus == MapScrollFocus(stageID: "chapter-1-stage-2", revision: 2))

        // Direct setter shares the same persistence write-through.
        state.play.mapScrollStageID = "chapter-3-gate"
        #expect(try makeState().play.mapScrollStageID == "chapter-3-gate")
    }
}
