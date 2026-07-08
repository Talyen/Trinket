import Foundation
import Testing
import TrinketPersistence

@MainActor
final class PlayerShellSessionStoreTests {
    let directoryURL: URL

    init() throws {
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerShellSessionStoreTests")
    }

    deinit {
        SaveTestSupport.removeTempDirectory(directoryURL)
    }

    @Test func persistsSelectedTabAcrossReload() {
        let storeURL = directoryURL.appending(path: "shell.store")
        let store = PlayerShellSessionStore(storeURL: storeURL)
        store.selectedTab = .options

        let reloaded = PlayerShellSessionStore(storeURL: storeURL)
        #expect(reloaded.selectedTab == .options)
    }

    @Test func migratesLegacyUserDefaultsOnFirstLaunch() {
        let defaults = UserDefaults(suiteName: "PlayerShellSessionStoreTests.\(UUID().uuidString)")!
        defaults.set("homestead", forKey: PlayerShellSessionStore.legacySessionTabKey)
        defaults.set("chapter-1-stage-2", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)

        let storeURL = directoryURL.appending(path: "migrate-shell.store")
        let store = PlayerShellSessionStore(storeURL: storeURL, legacyUserDefaults: defaults)

        #expect(store.selectedTab == .homestead)
        #expect(store.activeBattleStageID == "chapter-1-stage-2")
        #expect(defaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == nil)
    }

    @Test func clearBattleStateRemovesBattleAndScrollTargets() {
        let storeURL = directoryURL.appending(path: "clear-shell.store")
        let store = PlayerShellSessionStore(storeURL: storeURL)
        store.activeBattleStageID = "chapter-1-stage-1"
        store.mapScrollStageID = "chapter-1-stage-2"

        store.clearBattleState()

        let reloaded = PlayerShellSessionStore(storeURL: storeURL)
        #expect(reloaded.activeBattleStageID == nil)
        #expect(reloaded.mapScrollStageID == nil)
        #expect(reloaded.selectedTab == store.selectedTab)
    }
}
