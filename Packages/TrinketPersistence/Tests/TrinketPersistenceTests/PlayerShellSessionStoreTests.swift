import Foundation
import Testing
import TrinketPersistence
import TrinketTestSupport

@MainActor
final class PlayerShellSessionStoreTests {
    let directoryURL: URL

    init() throws {
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerShellSessionStoreTests")
    }

    deinit {
        SaveTestSupport.removeTempDirectory(directoryURL)
    }

    @Test func persistsSelectedTabAcrossReload() throws {
        let storeURL = directoryURL.appending(path: "shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.selectedTab = .options

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.selectedTab == .options)
    }

    @Test func migratesLegacyUserDefaultsOnFirstLaunch() throws {
        let defaults = UserDefaults(suiteName: "PlayerShellSessionStoreTests.\(UUID().uuidString)")!
        defaults.set("homestead", forKey: PlayerShellSessionStore.legacySessionTabKey)
        defaults.set("chapter-1-stage-2", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)

        let storeURL = directoryURL.appending(path: "migrate-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL, legacyUserDefaults: defaults)

        try #expect(store.selectedTab == .homestead)
        try #expect(store.activeBattleStageID == "chapter-1-stage-2")
        try #expect(defaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == nil)
    }

    @Test func clearBattleStateRemovesBattleAndScrollTargets() throws {
        let storeURL = directoryURL.appending(path: "clear-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.activeBattleStageID = "chapter-1-stage-1"
        store.mapScrollStageID = "chapter-1-stage-2"

        store.clearBattleState()

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.activeBattleStageID == nil)
        try #expect(reloaded.mapScrollStageID == nil)
        try #expect(reloaded.selectedTab == store.selectedTab)
    }
}
