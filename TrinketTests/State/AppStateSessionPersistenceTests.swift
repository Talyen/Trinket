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

    @Test func migratesLegacyShellKeysWithAppStatePolicy() throws {
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: PlayerShellSessionStore.legacySessionTabKey)
        context.userDefaults.set("chapter-1-stage-3", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)
        context.userDefaults.set("chapter-2-stage-1", forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey)

        let state = try makeState()

        // App policy: relaunch always lands on Play even when a legacy tab was stored.
        #expect(state.selectedTab == .play)
        #expect(context.userDefaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == nil)
        // Battles are never restored from legacy shell keys.
        #expect(state.battle.activeBattle == nil)
        #expect(context.userDefaults.string(forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey) == nil)
        // Map scroll target still restores.
        #expect(state.mapScrollStageID == "chapter-2-stage-1")
    }

    @Test func selectedTabPersistsOnChangeButRelaunchLandsOnPlay() throws {
        let state = try makeState()
        state.selectedTab = .options

        #expect(try makeState().selectedTab == .play)
    }

    @Test func noteMapScrollFocusPersistsPublishesAndBumpsRevision() throws {
        let state = try makeState()

        state.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.mapScrollStageID == "chapter-1-stage-2")
        #expect(state.mapScrollFocus == MapScrollFocus(stageID: "chapter-1-stage-2", revision: 1))
        #expect(try makeState().mapScrollStageID == "chapter-1-stage-2")

        state.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.mapScrollFocus == MapScrollFocus(stageID: "chapter-1-stage-2", revision: 2))

        // Direct setter shares the same persistence write-through.
        state.mapScrollStageID = "chapter-3-gate"
        #expect(try makeState().mapScrollStageID == "chapter-3-gate")
    }
}
