import Foundation
import SwiftData
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

    @Test func roundTripMatrixPersistsAndResetsShellState() throws {
        let storeURL = directoryURL.appending(path: "shell-round-trip.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(store.lastPlayMode == .campaign)

        store.selectedTab = .options
        store.mapScrollStageID = "chapter-1-stage-3"
        store.lastPlayMode = .labyrinth
        store.flushPendingPersistence()

        var reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.selectedTab == .options)
        try #expect(reloaded.mapScrollStageID == "chapter-1-stage-3")
        try #expect(reloaded.lastPlayMode == .labyrinth)

        reloaded.clearMapScrollState()
        reloaded.resetToDefaults(selectingTab: .homestead)
        reloaded.flushPendingPersistence()

        reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.selectedTab == .homestead)
        try #expect(reloaded.mapScrollStageID == nil)
        try #expect(reloaded.lastPlayMode == .campaign)
    }

    @Test func legacyMigrationMatrixRemapsAndCleansLegacyState() throws {
        let defaults = try #require(UserDefaults(suiteName: "PlayerShellSessionStoreTests.\(UUID().uuidString)"))
        let savedAt = Date(timeIntervalSince1970: 1700000456)
        let backgroundedAt = Date(timeIntervalSince1970: 1700000789)
        defaults.set("search", forKey: PlayerShellSessionStore.legacySessionTabKey)
        defaults.set("chapter-1-stage-4", forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey)
        defaults.set("chapter-1-stage-5", forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey)
        defaults.set(savedAt.timeIntervalSince1970, forKey: PlayerShellSessionStore.legacyActiveBattleSavedAtKey)
        defaults.set(2, forKey: PlayerShellSessionStore.legacyActiveBattleSchemaVersionKey)
        defaults.set(backgroundedAt.timeIntervalSince1970, forKey: PlayerShellSessionStore.legacyLastBackgroundedTimeKey)
        defaults.set(["hero-knight", "companion-panther"], forKey: PlayerShellSessionStore.legacyViewedCombatantIDsKey)

        let storeURL = directoryURL.appending(path: "migrate-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL, legacyUserDefaults: defaults)

        try #expect(store.selectedTab == .collection)
        try #expect(store.mapScrollStageID == "chapter-1-stage-5")
        try #expect(defaults.string(forKey: PlayerShellSessionStore.legacySessionTabKey) == nil)
        try #expect(defaults.string(forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey) == nil)
        try #expect(defaults.object(forKey: PlayerShellSessionStore.legacyViewedCombatantIDsKey) == nil)
        try #expect(defaults.string(forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey) == nil)

        let persistedSchema = Schema([PlayerShellSession.self])
        let persistedURL = directoryURL.appending(path: "legacy-record.store")
        let config = ModelConfiguration(schema: persistedSchema, url: persistedURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: persistedSchema, configurations: [config])
        let context = ModelContext(container)
        let record = PlayerShellSession()
        record.selectedTabRaw = "search"
        context.insert(record)
        try context.save()

        let persistedStore = try PlayerShellSessionStore(storeURL: persistedURL)
        try #expect(persistedStore.selectedTab == .collection)
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

    @Test func remapsLegacyAspectsPlayModeToSpires() throws {
        let storeURL = directoryURL.appending(path: "legacy-aspects-mode.store")
        let schema = Schema([PlayerShellSession.self])
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let record = PlayerShellSession()
        record.selectedTabRaw = "play"
        record.lastPlayModeRaw = "aspects"
        context.insert(record)
        try context.save()

        let store = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(store.lastPlayMode == .spires)

        let reloadedContext = try ModelContext(ModelContainer(for: schema, configurations: [config]))
        let descriptor = FetchDescriptor<PlayerShellSession>()
        let reloaded = try #require(try reloadedContext.fetch(descriptor).first { $0.id == "current" })
        try #expect(reloaded.lastPlayModeRaw == PlayerShellSessionPlayMode.spires.rawValue)
    }
}
