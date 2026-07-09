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
        store.setAspectBattleResume(aspectID: "ironVein", floor: 2)
        store.mapScrollStageID = "chapter-1-stage-2"

        store.clearBattleState()

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.activeBattleStageID == nil)
        try #expect(reloaded.activeBattleAspectID == nil)
        try #expect(reloaded.activeBattleAspectFloor == nil)
        try #expect(reloaded.mapScrollStageID == nil)
        try #expect(reloaded.selectedTab == store.selectedTab)
    }

    @Test func aspectBattleResumePersistsAcrossReload() throws {
        let storeURL = directoryURL.appending(path: "aspect-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.setAspectBattleResume(aspectID: "cinderSpire", floor: 4)

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.activeBattleStageID == nil)
        try #expect(reloaded.activeBattleAspectID == "cinderSpire")
        try #expect(reloaded.activeBattleAspectFloor == 4)
        try #expect(reloaded.hasActiveBattleResumeToken)
    }

    @Test func markCombatantAsViewedPersistsAcrossReload() throws {
        let storeURL = directoryURL.appending(path: "viewed-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.markCombatantAsViewed(id: "hero-knight")
        store.markCombatantAsViewed(id: "hero-knight")
        store.markCombatantAsViewed(id: "pet-panther")

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.viewedCombatantIDs == Set(["hero-knight", "pet-panther"]))
    }

    @Test func resetToDefaultsClearsBattleStateAndViewedCombatants() throws {
        let storeURL = directoryURL.appending(path: "reset-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.selectedTab = .collection
        store.activeBattleStageID = "chapter-1-stage-1"
        store.mapScrollStageID = "chapter-1-stage-2"
        store.viewedCombatantIDs = ["hero-knight"]
        store.acknowledgedHomesteadActionableFingerprint = "wheatField"
        store.lastBackgroundedTime = Date(timeIntervalSince1970: 1_700_000_000)

        store.resetToDefaults(selectingTab: .homestead)

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.selectedTab == .homestead)
        try #expect(reloaded.activeBattleStageID == nil)
        try #expect(reloaded.mapScrollStageID == nil)
        try #expect(reloaded.activeBattleSavedAt == nil)
        try #expect(reloaded.activeBattleSchemaVersion == nil)
        try #expect(reloaded.lastBackgroundedTime == nil)
        try #expect(reloaded.viewedCombatantIDs.isEmpty)
        try #expect(reloaded.acknowledgedHomesteadActionableFingerprint.isEmpty)
    }

    @Test func persistsHomesteadActionableFingerprintAcrossReload() throws {
        let storeURL = directoryURL.appending(path: "homestead-ack-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        store.acknowledgedHomesteadActionableFingerprint = "wheatField|lumberMill"

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.acknowledgedHomesteadActionableFingerprint == "wheatField|lumberMill")
    }

    @Test func persistsMapScrollAndBackgroundedTimeAcrossReload() throws {
        let storeURL = directoryURL.appending(path: "scroll-shell.store")
        let store = try PlayerShellSessionStore(storeURL: storeURL)
        let backgroundedAt = Date(timeIntervalSince1970: 1_700_000_123)
        store.mapScrollStageID = "chapter-1-stage-3"
        store.lastBackgroundedTime = backgroundedAt

        let reloaded = try PlayerShellSessionStore(storeURL: storeURL)
        try #expect(reloaded.mapScrollStageID == "chapter-1-stage-3")
        try #expect(reloaded.lastBackgroundedTime == backgroundedAt)
    }

    @Test func migratesExtendedLegacyUserDefaultsOnFirstLaunch() throws {
        let defaults = UserDefaults(suiteName: "PlayerShellSessionStoreTests.extended.\(UUID().uuidString)")!
        let savedAt = Date(timeIntervalSince1970: 1_700_000_456)
        let backgroundedAt = Date(timeIntervalSince1970: 1_700_000_789)
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
        try #expect(store.activeBattleStageID == "chapter-1-stage-4")
        try #expect(store.mapScrollStageID == "chapter-1-stage-5")
        try #expect(store.activeBattleSavedAt == savedAt)
        try #expect(store.activeBattleSchemaVersion == 2)
        try #expect(store.lastBackgroundedTime == backgroundedAt)
        try #expect(store.viewedCombatantIDs == Set(["hero-knight", "pet-panther"]))
        try #expect(defaults.string(forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey) == nil)
        try #expect(defaults.object(forKey: PlayerShellSessionStore.legacyViewedCombatantIDsKey) == nil)
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
}
