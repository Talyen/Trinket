import Foundation
import Observation
import os
import SwiftData

@MainActor
@Observable
public final class PlayerShellSessionStore {
    public static let legacySessionTabKey = "session.selectedTab"
    /// Discarded battle-resume / map-scroll keys — cleared on reset, never restored.
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

    /// Raw `AppTab` value. Persistence stores the string; AppState maps to `AppTab`.
    public var selectedTabRaw: String = "play" {
        didSet { persistSelectedTab() }
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
        let resolvedTab = Self.normalizedTabRaw(record.selectedTabRaw)
        selectedTabRaw = resolvedTab

        // Property observers do not run during init; rewrite remapped legacy tabs
        // (e.g. "search" → collection) and first-create records explicitly.
        if loadResult.needsInitialSave || record.selectedTabRaw != resolvedTab {
            record.selectedTabRaw = resolvedTab
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

    public func resetToDefaults(selectingTabRaw raw: String = "play") {
        selectedTabRaw = Self.normalizedTabRaw(raw)
        flushPendingPersistence()
    }

    private func persistSelectedTab() {
        record.selectedTabRaw = selectedTabRaw
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

    /// Must stay aligned with `AppTab` raw values in TrinketAppState (Persistence
    /// cannot import AppState).
    private static let knownTabRaws: Set<String> = [
        "play",
        "collection",
        "homestead",
        "options",
    ]

    private static func normalizedTabRaw(_ rawValue: String) -> String {
        if rawValue == "search" {
            return "collection"
        }
        return knownTabRaws.contains(rawValue) ? rawValue : "play"
    }
}
