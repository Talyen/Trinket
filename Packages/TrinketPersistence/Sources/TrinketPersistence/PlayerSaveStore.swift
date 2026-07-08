import Foundation
import Observation
import os
import SwiftData
import TrinketContent

@MainActor
@Observable
public final class PlayerSaveStore {
    public static let cloudKitContainerIdentifier = "iCloud.com.ryanmcintire.Trinket"

    private let container: ModelContainer
    private let context: ModelContext
    private var root: PlayerSaveRoot
    private var deferredSaveTask: Task<Void, Never>?
    private var pendingRollbackSnapshot: PlayerSave?
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave"
    )

    public private(set) var lastPersistenceError: PlayerSavePersistenceError?

    /// `true` when disk store failed and an in-memory fallback container is active.
    public private(set) var isPersistenceDegraded = false

    #if DEBUG
    var forcesNextSaveFailure = false
    #endif

    public var journey: JourneyProgressState {
        get { currentSave.journey }
        set { mutate { $0.journey = PlayerSaveSanitizer.sanitizeJourney(newValue) } }
    }

    public var roster: PlayerRosterState {
        get { currentSave.roster }
        set { mutate { $0.roster = newValue } }
    }

    public var inventory: PlayerInventoryState {
        get { currentSave.inventory }
        set { mutate { $0.inventory = newValue } }
    }

    public var homestead: PlayerHomesteadState {
        get { currentSave.homestead }
        set { mutate { $0.homestead = newValue } }
    }

    public var currentSave: PlayerSave {
        root.toPlayerSave()
    }

    private let persistSaveImmediately: Bool

    public init(
        storeName: String? = nil,
        storeURL: URL? = nil,
        disableCloudSync: Bool = false,
        resetState: Bool = false,
        inMemoryOnly: Bool = false,
        persistSaveImmediately: Bool = false
    ) throws {
        self.persistSaveImmediately = persistSaveImmediately
        let finalURL = Self.resolveStoreURL(storeName: storeName, storeURL: storeURL)

        if resetState, !inMemoryOnly {
            Self.cleanStoreFiles(at: finalURL)
        }

        let schema = PlayerSaveGraph.schema
        let resolved = Self.resolveConfiguration(
            schema: schema,
            finalURL: finalURL,
            storeName: storeName,
            storeURL: storeURL,
            disableCloudSync: disableCloudSync,
            inMemoryOnly: inMemoryOnly
        )

        let openResult = try ModelContainerBootstrap.open(
            schema: schema,
            primaryConfiguration: resolved.config,
            logger: logger,
            logLabel: "player save",
            storeURLForRecovery: resolved.recoveryURL,
            deleteStoreOnFailure: !inMemoryOnly
        )
        container = openResult.container
        if openResult.usedInMemoryFallback {
            isPersistenceDegraded = true
            lastPersistenceError = .storeUnavailable(
                "Couldn't open on-device save storage. Progress is kept in memory until you restart after freeing space."
            )
        }
        context = ModelContext(container)
        context.autosaveEnabled = false

        if resetState {
            Self.clearSaveRoot(in: context, logger: logger)
        }

        if let existingRoot = Self.fetchRoot(in: context, logger: logger) {
            root = existingRoot
            ensureRequiredGraph()
        } else {
            let newRoot = PlayerSaveRoot(save: PlayerSaveSanitizer.sanitize(.fresh))
            context.insert(newRoot)
            root = newRoot
            do {
                try context.save()
            } catch {
                lastPersistenceError = .writeFailed
                logger.error(
                    "Failed to save initial player save root: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    public func performBatchMutation(
        _ update: (inout PlayerSave) -> Void,
        persistImmediately: Bool = true
    ) throws {
        let snapshot = currentSave
        var candidate = snapshot
        update(&candidate)
        candidate.modifiedAt = Date()
        candidate = PlayerSaveSanitizer.sanitize(candidate)
        try PlayerSaveSanitizer.validate(candidate)
        root.update(from: candidate)

        if persistImmediately {
            do {
                try saveGraph()
                lastPersistenceError = nil
            } catch {
                root.update(from: snapshot)
                lastPersistenceError = .writeFailed
                logger.error("Failed to save SwiftData player graph: \(error.localizedDescription, privacy: .public)")
                throw PlayerSavePersistenceError.writeFailed
            }
        } else {
            pendingRollbackSnapshot = snapshot
        }
    }

    public func flushPendingSave() async {
        await Task.yield()
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        do {
            try saveGraph()
            pendingRollbackSnapshot = nil
            lastPersistenceError = nil
        } catch {
            rollbackPendingMutationIfNeeded()
            lastPersistenceError = .writeFailed
            logger.error("Failed to flush deferred SwiftData save: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleDeferredSave() {
        deferredSaveTask?.cancel()
        deferredSaveTask = Task(priority: .utility) { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            do {
                try self.saveGraph()
                self.pendingRollbackSnapshot = nil
                self.lastPersistenceError = nil
            } catch {
                self.rollbackPendingMutationIfNeeded()
                self.lastPersistenceError = .writeFailed
                self.logger.error(
                    "Failed to persist deferred player graph mutation: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func rollbackPendingMutationIfNeeded() {
        guard let pendingRollbackSnapshot else { return }
        root.update(from: pendingRollbackSnapshot)
        self.pendingRollbackSnapshot = nil
    }

    private func resetRoot(with save: PlayerSave) throws {
        do {
            try context.delete(model: PlayerSaveRoot.self)
            try context.save()
        } catch {
            logger.error(
                "Failed to clear existing save root: \(error.localizedDescription, privacy: .public)"
            )
        }

        let newRoot = PlayerSaveRoot(save: PlayerSaveSanitizer.sanitize(save))
        context.insert(newRoot)
        try saveGraph()

        root = newRoot
        pendingRollbackSnapshot = nil
    }

    public func resetGameplayProgress() throws {
        var fresh = PlayerSave.fresh
        fresh.sessionGeneration = currentSave.sessionGeneration &+ 1
        try resetRoot(with: fresh)
    }

    public func applyTestSeed() throws {
        try resetRoot(with: .testSeed)
    }

    private func mutate(_ update: (inout PlayerSave) -> Void) {
        do {
            try performBatchMutation(update, persistImmediately: persistSaveImmediately)
            if !persistSaveImmediately {
                scheduleDeferredSave()
            }
        } catch let error as PlayerSavePersistenceError {
            lastPersistenceError = error
            logger.error("Failed to persist player graph mutation: \(error.localizedDescription, privacy: .public)")
        } catch {
            lastPersistenceError = .writeFailed
            logger.error("Failed to persist player graph mutation: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func saveGraph() throws {
        do {
            #if DEBUG
            if forcesNextSaveFailure {
                forcesNextSaveFailure = false
                throw NSError(domain: "PlayerSaveStoreTests", code: 1)
            }
            #endif
            try context.save()
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = .writeFailed
            throw PlayerSavePersistenceError.writeFailed
        }
    }

    private func ensureRequiredGraph() {
        var save = currentSave
        save = PlayerSaveSanitizer.sanitize(save)
        root.update(from: save)
        do {
            try context.save()
        } catch {
            lastPersistenceError = .writeFailed
            logger.error(
                "Failed to persist sanitized player graph: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func fetchRoot(in context: ModelContext, logger: Logger) -> PlayerSaveRoot? {
        let descriptor = FetchDescriptor<PlayerSaveRoot>()
        do {
            return try context.fetch(descriptor).first { $0.id == "primary" }
        } catch {
            logger.error(
                "Failed to fetch player save root: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private static func resolveStoreURL(storeName: String?, storeURL: URL?) -> URL {
        if let storeName {
            return URL.applicationSupportDirectory.appending(path: "\(storeName).store")
        } else {
            return storeURL ?? URL.applicationSupportDirectory.appending(path: "default.store")
        }
    }

    private static func cleanStoreFiles(at url: URL) {
        let shmURL = url.deletingPathExtension().appendingPathExtension("store-shm")
        let walURL = url.deletingPathExtension().appendingPathExtension("store-wal")
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: shmURL)
        try? FileManager.default.removeItem(at: walURL)
    }

    private static func resolveConfiguration(
        schema: Schema,
        finalURL: URL,
        storeName: String?,
        storeURL: URL?,
        disableCloudSync: Bool,
        inMemoryOnly: Bool
    ) -> (config: ModelConfiguration, recoveryURL: URL?) {
        if inMemoryOnly {
            return (ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none), nil)
        } else if storeName != nil {
            return (ModelConfiguration(schema: schema, url: finalURL, cloudKitDatabase: .none), finalURL)
        } else if let storeURL {
            return (ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none), storeURL)
        } else if disableCloudSync {
            return (ModelConfiguration(schema: schema, cloudKitDatabase: .none), nil)
        } else {
            return (ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerIdentifier)), nil)
        }
    }

    private static func clearSaveRoot(in context: ModelContext, logger: Logger) {
        do {
            try context.delete(model: PlayerSaveRoot.self)
            try context.save()
        } catch {
            logger.error(
                "Failed to clear player save during reset: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    public func buildOrUpgradeHomesteadNode(_ definition: HomesteadNodeDefinition) -> HomesteadBuildResult {
        var didUpgrade = false
        do {
            try performBatchMutation { save in
                var homestead = save.homestead
                var rosterState = save.roster
                guard homestead.buildOrUpgrade(definition, roster: &rosterState) else { return }
                save.homestead = homestead
                save.roster = rosterState
                didUpgrade = true
            }
        } catch {
            return .persistFailed
        }
        return didUpgrade ? .success : .insufficientResources
    }
}
