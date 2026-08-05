import Foundation
import Observation
import os
import SwiftData

@MainActor
@Observable
public final class PlayerShellSessionStore {
    public static let legacySessionTabKey = "session.selectedTab"
    public static let legacyActiveBattleStageIDKey = "session.activeBattleStageID"
    public static let legacyMapScrollStageIDKey = "session.mapScrollStageID"
    public static let legacyActiveBattleSavedAtKey = "session.activeBattleSavedAt"
    public static let legacyActiveBattleSchemaVersionKey = "session.activeBattleSchemaVersion"
    public static let legacyLastBackgroundedTimeKey = "session.lastBackgroundedTime"
    /// Cleared on reset via `clearLegacyKeys` — Collection attention was removed;
    /// do not restore into session state.
    public static let legacyViewedCombatantIDsKey = "session.viewedCombatantIDs"

    private let context: ModelContext
    private var record: PlayerShellSession
    /// Coalesces rapid tab switches so `tab-round-trip` does not pay a SwiftData
    /// `context.save()` on every selection change.
    private var selectedTabSaveTask: Task<Void, Never>?
    private static let selectedTabSaveDelay: Duration = .milliseconds(300)
    private static let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerShellSession"
    )

    public var selectedTab: PlayerShellSessionTab = .play {
        didSet { persistSelectedTab() }
    }

    public var mapScrollStageID: String? {
        didSet { persistMapScrollStageID() }
    }

    public var lastPlayMode: PlayerShellSessionPlayMode = .campaign {
        didSet { persistLastPlayMode() }
    }

    public init(
        storeName: String? = nil,
        storeURL: URL? = nil,
        resetState: Bool = false,
        inMemoryOnly: Bool = false
    ) throws {
        let finalURL = Self.resolveStoreURL(storeName: storeName, storeURL: storeURL)

        if resetState, !inMemoryOnly {
            PlayerSaveStoreConfiguration.cleanStoreFiles(at: finalURL)
        }

        let schema = Schema([PlayerShellSession.self])
        let config = inMemoryOnly
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(schema: schema, url: finalURL, cloudKitDatabase: .none)

        let openResult = try ModelContainerBootstrap.open(
            schema: schema,
            primaryConfiguration: config,
            logger: Self.logger,
            logLabel: "shell session",
            storeURLForRecovery: inMemoryOnly ? nil : finalURL,
            deleteStoreOnFailure: !inMemoryOnly
        )
        context = ModelContext(openResult.container)
        context.autosaveEnabled = false

        if resetState {
            Self.clearShellSession(in: context)
        }

        let loadResult = Self.loadOrCreateRecord(in: context)
        record = loadResult.record
        let resolvedTab = Self.tab(from: record.selectedTabRaw) ?? .play
        selectedTab = resolvedTab
        mapScrollStageID = record.mapScrollStageID
        lastPlayMode = Self.playMode(from: record.lastPlayModeRaw) ?? .campaign

        // Property observers do not run during init; rewrite remapped legacy tabs
        // (e.g. "search" → collection), legacy play modes ("aspects" → spires),
        // and first-create records explicitly.
        let needsPlayModeRewrite = record.lastPlayModeRaw != lastPlayMode.rawValue
        if loadResult.needsInitialSave || record.selectedTabRaw != resolvedTab.rawValue || needsPlayModeRewrite {
            record.selectedTabRaw = resolvedTab.rawValue
            record.lastPlayModeRaw = lastPlayMode.rawValue
            saveContext()
        }
    }

    private static func resolveStoreURL(storeName: String?, storeURL: URL?) -> URL {
        if let storeName {
            URL.applicationSupportDirectory.appending(path: "\(storeName)-shell.store")
        } else if let storeURL {
            storeURL
        } else {
            URL.applicationSupportDirectory.appending(path: "shell-session.store")
        }
    }

    private static func clearShellSession(in context: ModelContext) {
        do {
            try context.delete(model: PlayerShellSession.self)
            try context.save()
        } catch {
            logger.error(
                "Failed to clear shell session during reset: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func loadOrCreateRecord(in context: ModelContext) -> (record: PlayerShellSession, needsInitialSave: Bool) {
        if let existing = fetchRecord(in: context) {
            return (existing, false)
        }
        let newRecord = PlayerShellSession()
        context.insert(newRecord)
        return (newRecord, true)
    }

    public func clearMapScrollState() {
        mapScrollStageID = nil
    }

    public func resetToDefaults(selectingTab tab: PlayerShellSessionTab = .play) {
        selectedTab = tab
        clearMapScrollState()
        lastPlayMode = .campaign
        flushPendingPersistence()
    }

    private func persistSelectedTab() {
        record.selectedTabRaw = selectedTab.rawValue
        record.updatedAt = .now
        selectedTabSaveTask?.cancel()
        selectedTabSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.selectedTabSaveDelay)
            guard let self, !Task.isCancelled else { return }
            saveContext()
            selectedTabSaveTask = nil
        }
    }

    public static func clearLegacyKeys(from defaults: UserDefaults) {
        defaults.removeObject(forKey: legacySessionTabKey)
        defaults.removeObject(forKey: legacyActiveBattleStageIDKey)
        defaults.removeObject(forKey: legacyMapScrollStageIDKey)
        defaults.removeObject(forKey: legacyActiveBattleSavedAtKey)
        defaults.removeObject(forKey: legacyActiveBattleSchemaVersionKey)
        defaults.removeObject(forKey: legacyLastBackgroundedTimeKey)
        defaults.removeObject(forKey: legacyViewedCombatantIDsKey)
    }

    /// Writes any coalesced tab selection immediately. Call before opening a
    /// second store against the same URL in tests, or before process teardown.
    public func flushPendingPersistence() {
        selectedTabSaveTask?.cancel()
        selectedTabSaveTask = nil
        saveContext()
    }

    private func persistMapScrollStageID() {
        record.mapScrollStageID = mapScrollStageID
        record.updatedAt = .now
        saveContext()
    }

    private func persistLastPlayMode() {
        record.lastPlayModeRaw = lastPlayMode.rawValue
        record.updatedAt = .now
        saveContext()
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            Self.logger.error(
                "Failed to save shell session: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func fetchRecord(in context: ModelContext) -> PlayerShellSession? {
        let descriptor = FetchDescriptor<PlayerShellSession>()
        do {
            return try context.fetch(descriptor).first { $0.id == "current" }
        } catch {
            return nil
        }
    }

    private static func tab(from rawValue: String) -> PlayerShellSessionTab? {
        if rawValue == "search" {
            return .collection
        }
        return PlayerShellSessionTab(rawValue: rawValue)
    }

    private static func playMode(from rawValue: String) -> PlayerShellSessionPlayMode? {
        if rawValue == "aspects" {
            return .spires
        }
        return PlayerShellSessionPlayMode(rawValue: rawValue)
    }
}
