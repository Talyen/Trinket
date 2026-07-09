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
    public static let legacyViewedCombatantIDsKey = "session.viewedCombatantIDs"

    public static let currentSchemaVersion = 1

    private let context: ModelContext
    private var record: PlayerShellSession
    private static let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerShellSession"
    )

    public var selectedTab: PlayerShellSessionTab = .play {
        didSet { persistSelectedTab() }
    }

    public var activeBattleStageID: String? {
        didSet {
            persistBattleStageID()
            touchBattleMetadataIfNeeded()
        }
    }

    public var activeBattleAspectID: String? {
        didSet {
            persistBattleAspectID()
            touchBattleMetadataIfNeeded()
        }
    }

    public var activeBattleAspectFloor: Int? {
        didSet {
            persistBattleAspectFloor()
            touchBattleMetadataIfNeeded()
        }
    }

    public var mapScrollStageID: String? {
        didSet { persistMapScrollStageID() }
    }

    public var hasActiveBattleResumeToken: Bool {
        activeBattleStageID != nil || activeBattleAspectID != nil
    }

    public var activeBattleSavedAt: Date? {
        get { record.activeBattleSavedAt }
        set {
            record.activeBattleSavedAt = newValue
            record.updatedAt = .now
            saveContext()
        }
    }

    public var activeBattleSchemaVersion: Int? {
        get { record.activeBattleSchemaVersion }
        set {
            record.activeBattleSchemaVersion = newValue
            record.updatedAt = .now
            saveContext()
        }
    }

    public var lastBackgroundedTime: Date? {
        get { record.lastBackgroundedTime }
        set {
            record.lastBackgroundedTime = newValue
            record.updatedAt = .now
            saveContext()
        }
    }

    /// Legacy pre-schema-7 Collection attention. Migrated into `PlayerSave.collectionAttention` on bootstrap; do not write new viewed state here.
    public var viewedCombatantIDs: Set<String> = [] {
        didSet { persistViewedCombatantIDs() }
    }

    /// Last Homestead actionable fingerprint the player dismissed by visiting the Homestead tab.
    /// When the live actionable set changes (new affordable builds), the tab badge returns.
    public var acknowledgedHomesteadActionableFingerprint: String = "" {
        didSet { persistAcknowledgedHomesteadActionableFingerprint() }
    }

    @available(*, deprecated, message: "Use PlayerSave.collectionAttention via AppState.markCombatantAsViewed")
    public func markCombatantAsViewed(id: String) {
        guard !viewedCombatantIDs.contains(id) else { return }
        viewedCombatantIDs.insert(id)
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
            Self.cleanStoreFiles(at: finalURL)
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
        activeBattleStageID = record.activeBattleStageID
        activeBattleAspectID = record.activeBattleAspectID
        activeBattleAspectFloor = record.activeBattleAspectFloor
        mapScrollStageID = record.mapScrollStageID
        viewedCombatantIDs = Set(record.viewedCombatantIDs)
        acknowledgedHomesteadActionableFingerprint = record.acknowledgedHomesteadActionableFingerprint

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
            return URL.applicationSupportDirectory.appending(path: "\(storeName)-shell.store")
        } else if let storeURL {
            return storeURL
        } else {
            return URL.applicationSupportDirectory.appending(path: "shell-session.store")
        }
    }

    private static func cleanStoreFiles(at url: URL) {
        let shmURL = url.deletingPathExtension().appendingPathExtension("store-shm")
        let walURL = url.deletingPathExtension().appendingPathExtension("store-wal")
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: shmURL)
        try? FileManager.default.removeItem(at: walURL)
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

    public func clearBattleState() {
        clearActiveBattleResume()
        mapScrollStageID = nil
        lastBackgroundedTime = nil
    }

    public func clearActiveBattleResume() {
        activeBattleStageID = nil
        activeBattleAspectID = nil
        activeBattleAspectFloor = nil
        activeBattleSavedAt = nil
        activeBattleSchemaVersion = nil
    }

    /// Journey and Aspect resume tokens are mutually exclusive.
    public func setJourneyBattleResume(stageID: String) {
        activeBattleAspectID = nil
        activeBattleAspectFloor = nil
        activeBattleStageID = stageID
    }

    public func setAspectBattleResume(aspectID: String, floor: Int) {
        activeBattleStageID = nil
        activeBattleAspectID = aspectID
        activeBattleAspectFloor = floor
    }

    public func resetToDefaults(selectingTab tab: PlayerShellSessionTab = .play) {
        selectedTab = tab
        clearBattleState()
        viewedCombatantIDs = []
        acknowledgedHomesteadActionableFingerprint = ""
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
        if let battleStageID = defaults.string(forKey: Self.legacyActiveBattleStageIDKey) {
            activeBattleStageID = battleStageID
        }
        if let scrollStageID = defaults.string(forKey: Self.legacyMapScrollStageIDKey) {
            mapScrollStageID = scrollStageID
        }
        if let savedAtVal = defaults.object(forKey: Self.legacyActiveBattleSavedAtKey) as? Double {
            activeBattleSavedAt = Date(timeIntervalSince1970: savedAtVal)
        }
        if defaults.object(forKey: Self.legacyActiveBattleSchemaVersionKey) != nil {
            // `integer(forKey:)` bridges NSNumber; `as? Int` on `object(forKey:)` does not.
            activeBattleSchemaVersion = defaults.integer(forKey: Self.legacyActiveBattleSchemaVersionKey)
        }
        if let lastBgVal = defaults.object(forKey: Self.legacyLastBackgroundedTimeKey) as? Double {
            lastBackgroundedTime = Date(timeIntervalSince1970: lastBgVal)
        }
        if let viewedArray = defaults.stringArray(forKey: Self.legacyViewedCombatantIDsKey) {
            viewedCombatantIDs = Set(viewedArray)
        }

        Self.clearLegacyKeys(from: defaults)
    }

    private func persistSelectedTab() {
        record.selectedTabRaw = selectedTab.rawValue
        record.updatedAt = .now
        saveContext()
    }

    private func persistViewedCombatantIDs() {
        record.viewedCombatantIDs = Array(viewedCombatantIDs)
        record.updatedAt = .now
        saveContext()
    }

    private func persistAcknowledgedHomesteadActionableFingerprint() {
        record.acknowledgedHomesteadActionableFingerprint = acknowledgedHomesteadActionableFingerprint
        record.updatedAt = .now
        saveContext()
    }

    private func persistBattleStageID() {
        record.activeBattleStageID = activeBattleStageID
        record.updatedAt = .now
        saveContext()
    }

    private func persistBattleAspectID() {
        record.activeBattleAspectID = activeBattleAspectID
        record.updatedAt = .now
        saveContext()
    }

    private func persistBattleAspectFloor() {
        record.activeBattleAspectFloor = activeBattleAspectFloor
        record.updatedAt = .now
        saveContext()
    }

    private func touchBattleMetadataIfNeeded() {
        if hasActiveBattleResumeToken {
            activeBattleSavedAt = Date.now
            activeBattleSchemaVersion = Self.currentSchemaVersion
        } else if activeBattleStageID == nil, activeBattleAspectID == nil {
            activeBattleSavedAt = nil
            activeBattleSchemaVersion = nil
        }
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
