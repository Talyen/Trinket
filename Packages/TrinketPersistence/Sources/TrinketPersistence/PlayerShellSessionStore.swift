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

    private let context: ModelContext
    private var record: PlayerShellSession
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerShellSession"
    )

    public var selectedTab: PlayerShellSessionTab {
        didSet { persistSelectedTab() }
    }

    public var activeBattleStageID: String? {
        didSet { persistBattleStageID() }
    }

    public var mapScrollStageID: String? {
        didSet { persistMapScrollStageID() }
    }

    public init(
        storeName: String? = nil,
        storeURL: URL? = nil,
        resetState: Bool = false,
        inMemoryOnly: Bool = false,
        legacyUserDefaults: UserDefaults? = nil
    ) {
        let finalURL: URL
        if let storeName {
            finalURL = URL.applicationSupportDirectory.appending(path: "\(storeName)-shell.store")
        } else if let storeURL {
            finalURL = storeURL
        } else {
            finalURL = URL.applicationSupportDirectory.appending(path: "shell-session.store")
        }

        if resetState, !inMemoryOnly {
            let shmURL = finalURL.deletingPathExtension().appendingPathExtension("store-shm")
            let walURL = finalURL.deletingPathExtension().appendingPathExtension("store-wal")
            try? FileManager.default.removeItem(at: finalURL)
            try? FileManager.default.removeItem(at: shmURL)
            try? FileManager.default.removeItem(at: walURL)
        }

        let schema = Schema([PlayerShellSession.self])
        let config: ModelConfiguration
        if inMemoryOnly {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            config = ModelConfiguration(schema: schema, url: finalURL, cloudKitDatabase: .none)
        }

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            logger.error(
                "Failed to open shell session store: \(error.localizedDescription, privacy: .public)"
            )
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: fallbackConfig)
            } catch {
                fatalError(
                    "Failed to open fallback in-memory shell session store: \(error.localizedDescription)"
                )
            }
        }

        context = ModelContext(container)
        context.autosaveEnabled = false

        if resetState {
            do {
                try context.delete(model: PlayerShellSession.self)
                try context.save()
            } catch {
                logger.error(
                    "Failed to clear shell session during reset: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        if let existing = Self.fetchRecord(in: context) {
            record = existing
        } else {
            let newRecord = PlayerShellSession()
            context.insert(newRecord)
            record = newRecord
            saveContext()
        }

        selectedTab = Self.tab(from: record.selectedTabRaw) ?? .play
        activeBattleStageID = record.activeBattleStageID
        mapScrollStageID = record.mapScrollStageID

        if let legacyUserDefaults {
            migrateLegacyUserDefaultsIfNeeded(from: legacyUserDefaults)
        }
    }

    public func clearBattleState() {
        activeBattleStageID = nil
        mapScrollStageID = nil
    }

    public func resetToDefaults(selectingTab tab: PlayerShellSessionTab = .play) {
        selectedTab = tab
        clearBattleState()
    }

    public static func clearLegacyKeys(from defaults: UserDefaults) {
        defaults.removeObject(forKey: legacySessionTabKey)
        defaults.removeObject(forKey: legacyActiveBattleStageIDKey)
        defaults.removeObject(forKey: legacyMapScrollStageIDKey)
    }

    public func migrateLegacyUserDefaultsIfNeeded(from defaults: UserDefaults) {
        let hasLegacyValues = defaults.string(forKey: Self.legacySessionTabKey) != nil
            || defaults.string(forKey: Self.legacyActiveBattleStageIDKey) != nil
            || defaults.string(forKey: Self.legacyMapScrollStageIDKey) != nil
        guard hasLegacyValues else { return }

        if let rawTab = defaults.string(forKey: Self.legacySessionTabKey),
           let tab = Self.tab(from: rawTab) {
            selectedTab = tab
        }
        if let battleStageID = defaults.string(forKey: Self.legacyActiveBattleStageIDKey) {
            activeBattleStageID = battleStageID
        }
        if let scrollStageID = defaults.string(forKey: Self.legacyMapScrollStageIDKey) {
            mapScrollStageID = scrollStageID
        }

        Self.clearLegacyKeys(from: defaults)
    }

    private func persistSelectedTab() {
        record.selectedTabRaw = selectedTab.rawValue
        record.updatedAt = .now
        saveContext()
    }

    private func persistBattleStageID() {
        record.activeBattleStageID = activeBattleStageID
        record.updatedAt = .now
        saveContext()
    }

    private func persistMapScrollStageID() {
        record.mapScrollStageID = mapScrollStageID
        record.updatedAt = .now
        saveContext()
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            logger.error(
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
        PlayerShellSessionTab(rawValue: rawValue)
    }
}
