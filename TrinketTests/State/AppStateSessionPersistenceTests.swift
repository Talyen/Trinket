import Testing
import TrinketPersistence
@testable import Trinket

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
        #expect(state.mapScrollStageID == nil)
    }

    @Test func migratesPreviouslyStoredTabFromLegacyUserDefaultsButLandsOnPlay() throws {
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: PlayerShellSessionStore.legacySessionTabKey)

        let state = try makeState()

        #expect(state.selectedTab == .play)
        #expect(context.userDefaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == nil)
    }

    @Test func discardsLegacyBattleStageIDFromUserDefaults() throws {
        context.userDefaults.set("chapter-1-stage-3", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)

        let state = try makeState()

        #expect(state.battle.activeBattle == nil)
        #expect(context.userDefaults.string(forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey) == nil)
    }

    @Test func migratesPreviouslyStoredMapScrollStageIDFromLegacyUserDefaults() throws {
        context.userDefaults.set("chapter-2-stage-1", forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey)

        let state = try makeState()

        #expect(state.mapScrollStageID == "chapter-2-stage-1")
    }

    @Test func selectedTabPersistsOnChangeButRelaunchLandsOnPlay() throws {
        let state = try makeState()
        state.selectedTab = .options

        #expect(try makeState().selectedTab == .play)
    }

    @Test func mapScrollStageIDPersistsOnChange() throws {
        let state = try makeState()
        state.mapScrollStageID = "chapter-3-gate"

        #expect(try makeState().mapScrollStageID == "chapter-3-gate")
    }

    @Test func noteMapScrollFocusPersistsTargetAndPublishesFocus() throws {
        let state = try makeState()

        state.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.mapScrollStageID == "chapter-1-stage-2")
        #expect(state.mapScrollFocus == MapScrollFocus(stageID: "chapter-1-stage-2", revision: 1))
        #expect(try makeState().mapScrollStageID == "chapter-1-stage-2")
    }

    @Test func noteMapScrollFocusIncrementsRevisionWhenTargetUnchanged() throws {
        let state = try makeState()
        state.noteMapScrollFocus("chapter-1-stage-2")

        state.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.mapScrollFocus == MapScrollFocus(stageID: "chapter-1-stage-2", revision: 2))
    }
}
