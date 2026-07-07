import TrinketContent
import TrinketPersistence
import Testing
@testable import Trinket

@Suite @MainActor
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

    @Test func loadsPreviouslyStoredTab() {
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: AppState.sessionTabKey)

        let state = makeState()

        #expect(state.selectedTab == .homestead)
    }

    @Test func loadsPreviouslyStoredBattleStageID() {
        context.userDefaults.set("chapter-1-stage-3", forKey: AppState.activeBattleStageIDKey)

        let state = makeState()

        #expect(state.activeBattleStageID == "chapter-1-stage-3")
    }

    @Test func loadsPreviouslyStoredMapScrollStageID() {
        context.userDefaults.set("chapter-2-stage-1", forKey: AppState.mapScrollStageIDKey)

        let state = makeState()

        #expect(state.mapScrollStageID == "chapter-2-stage-1")
    }

    @Test func selectedTabPersistsOnChange() {
        let state = makeState()
        state.selectedTab = .options

        #expect(context.userDefaults.string(forKey: AppState.sessionTabKey) == AppTab.options.rawValue)
        #expect(makeState().selectedTab == .options)
    }

    @Test func activeBattleStageIDPersistsOnChange() {
        let state = makeState()
        state.activeBattleStageID = "chapter-1-stage-5"

        #expect(context.userDefaults.string(forKey: AppState.activeBattleStageIDKey) == "chapter-1-stage-5")
        #expect(makeState().activeBattleStageID == "chapter-1-stage-5")
    }

    @Test func mapScrollStageIDPersistsOnChange() {
        let state = makeState()
        state.mapScrollStageID = "chapter-3-gate"

        #expect(context.userDefaults.string(forKey: AppState.mapScrollStageIDKey) == "chapter-3-gate")
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

    @Test func noteMapScrollFocusPersistsTargetAndBumpsNonce() {
        let state = makeState()

        state.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.mapScrollStageID == "chapter-1-stage-2")
        #expect(state.mapScrollNonce == 1)
        #expect(context.userDefaults.string(forKey: AppState.mapScrollStageIDKey) == "chapter-1-stage-2")
    }

    @Test func noteMapScrollFocusCanForceNonceWhenTargetUnchanged() {
        let state = makeState()
        state.noteMapScrollFocus("chapter-1-stage-2")

        state.noteMapScrollFocus("chapter-1-stage-2", bumpEvenWhenUnchanged: true)

        #expect(state.mapScrollNonce == 2)
    }
}
