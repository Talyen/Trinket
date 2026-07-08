import Testing
import TrinketPersistence
@testable import Trinket

@MainActor
final class AppStateSessionPersistenceTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    private func makeState() -> AppState {
        context.makeAppState()
    }

    @Test func defaultsWhenNoStoredValues() {
        let state = makeState()

        #expect(state.selectedTab == .play)
        #expect(state.activeBattleStageID == nil)
        #expect(state.mapScrollStageID == nil)
    }

    @Test func migratesPreviouslyStoredTabFromLegacyUserDefaults() {
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: PlayerShellSessionStore.legacySessionTabKey)

        let state = makeState()

        #expect(state.selectedTab == .homestead)
        #expect(context.userDefaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == nil)
    }

    @Test func migratesPreviouslyStoredBattleStageIDFromLegacyUserDefaults() {
        context.userDefaults.set("chapter-1-stage-3", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)

        let state = makeState()

        #expect(state.activeBattleStageID == "chapter-1-stage-3")
    }

    @Test func migratesPreviouslyStoredMapScrollStageIDFromLegacyUserDefaults() {
        context.userDefaults.set("chapter-2-stage-1", forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey)

        let state = makeState()

        #expect(state.mapScrollStageID == "chapter-2-stage-1")
    }

    @Test func selectedTabPersistsOnChange() {
        let state = makeState()
        state.selectedTab = .options

        #expect(makeState().selectedTab == .options)
    }

    @Test func activeBattleStageIDPersistsOnChange() {
        let state = makeState()
        state.activeBattleStageID = "chapter-1-stage-5"

        #expect(makeState().activeBattleStageID == "chapter-1-stage-5")
    }

    @Test func mapScrollStageIDPersistsOnChange() {
        let state = makeState()
        state.mapScrollStageID = "chapter-3-gate"

        #expect(makeState().mapScrollStageID == "chapter-3-gate")
    }

    @Test func clearSessionBattleStateClearsBothBattleAndScrollKeys() {
        let state = makeState()
        state.activeBattleStageID = "chapter-1-stage-1"
        state.mapScrollStageID = "chapter-1-stage-2"

        state.clearSessionBattleState()

        #expect(state.activeBattleStageID == nil)
        #expect(state.mapScrollStageID == nil)
    }

    @Test func clearSessionBattleStateLeavesTabIntact() {
        let state = makeState()
        state.selectedTab = .homestead
        state.activeBattleStageID = "chapter-1-stage-1"

        state.clearSessionBattleState()

        #expect(state.selectedTab == .homestead)
        #expect(state.activeBattleStageID == nil)
    }

    @Test func noteMapScrollFocusPersistsTargetAndPublishesFocus() {
        let state = makeState()

        state.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.mapScrollStageID == "chapter-1-stage-2")
        #expect(state.mapScrollFocus == MapScrollFocus(stageID: "chapter-1-stage-2", revision: 1))
        #expect(makeState().mapScrollStageID == "chapter-1-stage-2")
    }

    @Test func noteMapScrollFocusIncrementsRevisionWhenTargetUnchanged() {
        let state = makeState()
        state.noteMapScrollFocus("chapter-1-stage-2")

        state.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.mapScrollFocus == MapScrollFocus(stageID: "chapter-1-stage-2", revision: 2))
    }
}
