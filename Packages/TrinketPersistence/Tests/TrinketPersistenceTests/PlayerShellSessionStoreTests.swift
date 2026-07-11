import Foundation
import SwiftData
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
        let defaults = try #require(UserDefaults(suiteName: "PlayerShellSessionStoreTests.\(UUID().uuidString)"))
        defaults.set("homestead", forKey: PlayerShellSessionStore.legacySessionTabKey)
        defaults.set("chapter-1-stage-2", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)

        let storeURL = directoryURL.appending(path: "migrate-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL, legacyUserDefaults: defaults)

        try #expect(store.selectedTab == .homestead)
        try #expect(defaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == nil)
        try #expect(defaults.string(forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey) == nil)
    }

    @Test func clearMapScrollStateRemovesScrollTarget() throws {
        let storeURL = directoryURL.appending(path: "clear-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.mapScrollStageID = "chapter-1-stage-2"

        store.clearMapScrollState()

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.mapScrollStageID == nil)
        try #expect(reloaded.selectedTab == store.selectedTab)
    }

    @Test func resetToDefaultsClearsMapScroll() throws {
        let storeURL = directoryURL.appending(path: "reset-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.selectedTab = .collection
        store.mapScrollStageID = "chapter-1-stage-2"

        store.resetToDefaults(selectingTab: .homestead)

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.selectedTab == .homestead)
        try #expect(reloaded.mapScrollStageID == nil)
    }

    @Test func persistsMapScrollAcrossReload() throws {
        let storeURL = directoryURL.appending(path: "scroll-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.mapScrollStageID = "chapter-1-stage-3"

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.mapScrollStageID == "chapter-1-stage-3")
    }

    @Test func persistsLastPlayModeAcrossReload() throws {
        let storeURL = directoryURL.appending(path: "play-mode-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(store.lastPlayMode == .campaign)

        store.lastPlayMode = .labyrinth

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.lastPlayMode == .labyrinth)
    }

    @Test func resetToDefaultsRestoresCampaignPlayMode() throws {
        let storeURL = directoryURL.appending(path: "reset-play-mode-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.lastPlayMode = .aspects

        store.resetToDefaults(selectingTab: .play)

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.lastPlayMode == .campaign)
    }

    @Test func migratesExtendedLegacyUserDefaultsOnFirstLaunch() throws {
        let defaults = try #require(UserDefaults(suiteName: "PlayerShellSessionStoreTests.extended.\(UUID().uuidString)"))
        let savedAt = Date(timeIntervalSince1970: 1700000456)
        let backgroundedAt = Date(timeIntervalSince1970: 1700000789)
        defaults.set("search", forKey: PlayerShellSessionStore.legacySessionTabKey)
        defaults.set("chapter-1-stage-4", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)
        defaults.set("chapter-1-stage-5", forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey)
        defaults.set(savedAt.timeIntervalSince1970, forKey: PlayerShellSessionStore.legacyActiveBattleSavedAtKey)
        defaults.set(2, forKey: PlayerShellSessionStore.legacyActiveBattleSchemaVersionKey)
        defaults.set(backgroundedAt.timeIntervalSince1970, forKey: PlayerShellSessionStore.legacyLastBackgroundedTimeKey)
        defaults.set(["hero-knight", "pet-panther"], forKey: PlayerShellSessionStore.legacyViewedCombatantIDsKey)

        let storeURL = directoryURL.appending(path: "migrate-extended-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL, legacyUserDefaults: defaults)

        try #expect(store.selectedTab == .collection)
        try #expect(store.mapScrollStageID == "chapter-1-stage-5")
        try #expect(defaults.string(forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey) == nil)
        try #expect(defaults.object(forKey: PlayerShellSessionStore.legacyViewedCombatantIDsKey) == nil)
        try #expect(defaults.string(forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey) == nil)
    }

    @Test func remapsPersistedLegacySearchTabToCollection() throws {
        let storeURL = directoryURL.appending(path: "remap-search-tab.store")
        let schema = Schema([PlayerShellSession.self])
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let record = PlayerShellSession()
        record.selectedTabRaw = "search"
        context.insert(record)
        try context.save()

        let store = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(store.selectedTab == .collection)

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.selectedTab == .collection)
    }

    @Test func clearsStaleBattleResumeFieldsOnLoad() throws {
        let storeURL = directoryURL.appending(path: "stale-battle-shell.store")
        let schema = Schema([PlayerShellSession.self])
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let record = PlayerShellSession()
        record.selectedTabRaw = "play"
        record.activeBattleStageID = "chapter-1-stage-1"
        record.activeBattleSavedAt = Date()
        record.activeBattleSchemaVersion = 1
        record.lastBackgroundedTime = Date()
        context.insert(record)
        try context.save()

        _ = try PlayerShellSessionStore(storeURL: storeURL)

        let reloadedContext = try ModelContext(ModelContainer(for: schema, configurations: [config]))
        let descriptor = FetchDescriptor<PlayerShellSession>()
        let reloaded = try #require(try reloadedContext.fetch(descriptor).first { $0.id == "current" })
        try #expect(reloaded.activeBattleStageID == nil)
        try #expect(reloaded.activeBattleSavedAt == nil)
        try #expect(reloaded.activeBattleSchemaVersion == nil)
        try #expect(reloaded.lastBackgroundedTime == nil)
    }
}
