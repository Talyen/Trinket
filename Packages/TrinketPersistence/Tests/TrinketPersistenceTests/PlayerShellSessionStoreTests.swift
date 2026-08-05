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

        store.selectedTabRaw = "options"
        store.flushPendingPersistence()

        var reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.selectedTabRaw == "options")

        reloaded.resetToDefaults(selectingTabRaw: "homestead")
        reloaded.flushPendingPersistence()

        reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.selectedTabRaw == "homestead")
    }

    @Test func legacyTabRemappingMatrix() throws {
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
        try #expect(persistedStore.selectedTabRaw == "collection")
    }

    @Test func unknownTabRawFallsBackToPlay() throws {
        let persistedSchema = Schema([PlayerShellSession.self])
        let persistedURL = directoryURL.appending(path: "unknown-tab.store")
        let config = ModelConfiguration(schema: persistedSchema, url: persistedURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: persistedSchema, configurations: [config])
        let context = ModelContext(container)
        let record = PlayerShellSession()
        record.selectedTabRaw = "not-a-tab"
        context.insert(record)
        try context.save()

        let store = try PlayerShellSessionStore(storeURL: persistedURL)
        try #expect(store.selectedTabRaw == "play")

        let reloaded = try PlayerShellSessionStore(storeURL: persistedURL)
        try #expect(reloaded.selectedTabRaw == "play")
    }
}
