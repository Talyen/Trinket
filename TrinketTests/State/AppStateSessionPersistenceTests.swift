import Testing
import TrinketPersistence
@testable import Trinket

@Suite @MainActor
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
        #expect(state.activeBattleStageID == nil)
        #expect(state.mapScrollStageID == nil)
    }

    @Test func migratesPreviouslyStoredTabFromLegacyUserDefaults() throws {
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: PlayerShellSessionStore.legacySessionTabKey)

        let state = try makeState()

        #expect(state.selectedTab == .homestead)
        #expect(context.userDefaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == nil)
    }

    @Test func migratesPreviouslyStoredBattleStageIDFromLegacyUserDefaults() throws {
        context.userDefaults.set("chapter-1-stage-3", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)

        let state = try makeState()

        #expect(state.activeBattleStageID == "chapter-1-stage-3")
    }

    @Test func migratesPreviouslyStoredMapScrollStageIDFromLegacyUserDefaults() throws {
        context.userDefaults.set("chapter-2-stage-1", forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey)

        let state = try makeState()

        #expect(state.mapScrollStageID == "chapter-2-stage-1")
    }

    @Test func selectedTabPersistsOnChange() throws {
        let state = try makeState()
        state.selectedTab = .options

        #expect(try makeState().selectedTab == .options)
    }

    @Test func activeBattleStageIDPersistsOnChange() throws {
        let state = try makeState()
        state.activeBattleStageID = "chapter-1-stage-5"

        #expect(try makeState().activeBattleStageID == "chapter-1-stage-5")
    }

    @Test func mapScrollStageIDPersistsOnChange() throws {
        let state = try makeState()
        state.mapScrollStageID = "chapter-3-gate"

        #expect(try makeState().mapScrollStageID == "chapter-3-gate")
    }

    @Test func clearSessionBattleStateClearsBothBattleAndScrollKeys() throws {
        let state = try makeState()
        state.activeBattleStageID = "chapter-1-stage-1"
        state.mapScrollStageID = "chapter-1-stage-2"

        state.clearSessionBattleState()

        #expect(state.activeBattleStageID == nil)
        #expect(state.mapScrollStageID == nil)
    }

    @Test func clearSessionBattleStateLeavesTabIntact() throws {
        let state = try makeState()
        state.selectedTab = .homestead
        state.activeBattleStageID = "chapter-1-stage-1"

        state.clearSessionBattleState()

        #expect(state.selectedTab == .homestead)
        #expect(state.activeBattleStageID == nil)
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
