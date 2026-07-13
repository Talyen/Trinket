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
    /// Cleared on migrate only — Collection attention was removed; do not restore into session state.
    public static let legacyViewedCombatantIDsKey = "session.viewedCombatantIDs"

    private let context: ModelContext
    private var record: PlayerShellSession
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
        inMemoryOnly: Bool = false,
        legacyUserDefaults: UserDefaults? = nil
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
        lastPlayMode = PlayerShellSessionPlayMode(rawValue: record.lastPlayModeRaw) ?? .campaign

        // Drop any leftover battle-resume fields from older builds.
        let hadStaleBattleResume = record.activeBattleStageID != nil
            || record.activeBattleAspectID != nil
            || record.activeBattleAspectFloor != nil
            || record.activeBattleLabyrinthNodeID != nil
            || record.activeBattleSavedAt != nil
            || record.activeBattleSchemaVersion != nil
            || record.lastBackgroundedTime != nil
        if hadStaleBattleResume {
            clearStaleBattleResumeFields()
        }

        // Property observers do not run during init; rewrite remapped legacy tabs
        // (e.g. "search" → collection) and first-create records explicitly.
        if loadResult.needsInitialSave || record.selectedTabRaw != resolvedTab.rawValue {
            record.selectedTabRaw = resolvedTab.rawValue
            saveContext()
        }

        if let legacyUserDefaults {
            migrateLegacyUserDefaultsIfNeeded(from: legacyUserDefaults)
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
        } else {
            let newRecord = PlayerShellSession()
            context.insert(newRecord)
            return (newRecord, true)
        }
    }

    public func clearMapScrollState() {
        mapScrollStageID = nil
    }

    public func resetToDefaults(selectingTab tab: PlayerShellSessionTab = .play) {
        selectedTab = tab
        clearMapScrollState()
        lastPlayMode = .campaign
        clearStaleBattleResumeFields()
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

    public func migrateLegacyUserDefaultsIfNeeded(from defaults: UserDefaults) {
        let hasLegacyValues = defaults.string(forKey: Self.legacySessionTabKey) != nil
            || defaults.string(forKey: Self.legacyActiveBattleStageIDKey) != nil
            || defaults.string(forKey: Self.legacyMapScrollStageIDKey) != nil
            || defaults.object(forKey: Self.legacyActiveBattleSavedAtKey) != nil
            || defaults.object(forKey: Self.legacyActiveBattleSchemaVersionKey) != nil
            || defaults.object(forKey: Self.legacyLastBackgroundedTimeKey) != nil
            || defaults.object(forKey: Self.legacyViewedCombatantIDsKey) != nil
        guard hasLegacyValues else { return }

        if let rawTab = defaults.string(forKey: Self.legacySessionTabKey),
           let tab = Self.tab(from: rawTab) {
            selectedTab = tab
        }
        if let scrollStageID = defaults.string(forKey: Self.legacyMapScrollStageIDKey) {
            mapScrollStageID = scrollStageID
        }
        // Legacy battle-resume / backgrounded keys are intentionally discarded.

        Self.clearLegacyKeys(from: defaults)
    }

    private func clearStaleBattleResumeFields() {
        record.activeBattleStageID = nil
        record.activeBattleAspectID = nil
        record.activeBattleAspectFloor = nil
        record.activeBattleLabyrinthNodeID = nil
        record.activeBattleSavedAt = nil
        record.activeBattleSchemaVersion = nil
        record.lastBackgroundedTime = nil
        record.updatedAt = .now
        saveContext()
    }

    private func persistSelectedTab() {
        record.selectedTabRaw = selectedTab.rawValue
        record.updatedAt = .now
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
}
