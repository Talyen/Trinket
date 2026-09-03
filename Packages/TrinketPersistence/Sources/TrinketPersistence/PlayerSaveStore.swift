import Foundation
import Observation
import os
import SwiftData
import TrinketContent

public enum PlayerSaveDefaults {
    public static let loggingSubsystem = "com.ryanmcintire.Trinket"
}

@MainActor
@Observable
public final class PlayerSaveStore {
    public static let cloudKitContainerIdentifier = "iCloud.com.ryanmcintire.Trinket"
    private static let performanceSignposter = OSSignposter(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PersistencePerformance",
    )

    private let container: ModelContainer
    private let context: ModelContext
    private var root: PlayerSaveRoot
    private var deferredSaveTask: Task<Void, Never>?
    private var pendingRollbackSnapshot: PlayerSave?
    private var pendingRollbackSlices: PlayerSaveSlice = []
    private var observedSave: PlayerSave = .fresh
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave",
    )

    public private(set) var lastPersistenceError: PlayerSavePersistenceError?

    public private(set) var isPersistenceDegraded = false

    public private(set) var recoveredAfterStoreDeletion = false
    public let isCloudSyncEnabled: Bool

    #if DEBUG
    public var forcesNextSaveFailure = false
    #endif

    public var journey: JourneyProgressState {
        get { observedSave.journey }
        set { mutate { $0.journey = newValue } }
    }

    public var roster: PlayerRosterState {
        get { observedSave.roster }
        set { mutate { $0.roster = newValue } }
    }

    public var inventory: PlayerInventoryState {
        get { observedSave.inventory }
        set { mutate { $0.inventory = newValue } }
    }

    public var homestead: PlayerHomesteadState {
        get { observedSave.homestead }
        set { mutate { $0.homestead = newValue } }
    }

    public var spires: PlayerSpiresState {
        get { observedSave.spires }
        set { mutate { $0.spires = newValue } }
    }

    public var labyrinth: PlayerLabyrinthState {
        get { observedSave.labyrinth }
        set { mutate { $0.labyrinth = newValue } }
    }

    public var corruptionAltarCooldownRemaining: Int {
        observedSave.corruptionAltarCooldownRemaining
    }

    public var worldSeed: UInt64 {
        observedSave.worldSeed
    }

    public var starterSelection: StarterSelectionState {
        observedSave.starterSelection
    }

    public var currentSave: PlayerSave {
        observedSave
    }

    private let persistSaveImmediately: Bool

    public init(
        storeName: String? = nil,
        storeURL: URL? = nil,
        disableCloudSync: Bool = false,
        resetState: Bool = false,
        inMemoryOnly: Bool = false,
        persistSaveImmediately: Bool = true,
    ) throws {
        let bootstrapInterval = Self.performanceSignposter.beginInterval("PlayerSaveBootstrap")
        defer {
            Self.performanceSignposter.endInterval("PlayerSaveBootstrap", bootstrapInterval)
        }
        self.persistSaveImmediately = persistSaveImmediately
        let requestedCloudSync = !disableCloudSync
            && !inMemoryOnly
            && storeName == nil
            && storeURL == nil
        let schema = PlayerSaveGraph.schema
        let resolved = PlayerSaveStoreConfiguration.resolveStore(
            schema: schema,
            storeName: storeName,
            storeURL: storeURL,
            disableCloudSync: disableCloudSync,
            inMemoryOnly: inMemoryOnly,
            cloudKitContainerIdentifier: Self.cloudKitContainerIdentifier,
        )

        if resetState, !inMemoryOnly {
            PlayerSaveStoreConfiguration.cleanStoreFiles(at: resolved.finalURL)
        }

        let openResult = try Self.openSaveContainer(
            schema: schema,
            configuration: resolved.config,
            recoveryURL: resolved.recoveryURL,
            logger: logger,
        )
        container = openResult.container
        isCloudSyncEnabled = requestedCloudSync && !openResult.usedInMemoryFallback
        if openResult.usedInMemoryFallback {
            isPersistenceDegraded = true
            lastPersistenceError = .storeUnavailable(
                "Couldn't open on-device save storage. Progress is kept in memory until you restart after freeing space.",
            )
        }
        if openResult.recoveredAfterStoreDeletion {
            recoveredAfterStoreDeletion = true
            lastPersistenceError = .storeUnavailable(
                "Saved progress was unreadable and couldn't be repaired, so a fresh start was created.",
            )
        }
        context = ModelContext(container)
        context.autosaveEnabled = false

        if resetState {
            try PlayerSaveStoreConfiguration.clearSaveRoot(in: context, logger: logger)
        }

        let loadedRoot = try Self.loadOrCreateRoot(in: context, logger: logger)
        root = loadedRoot.root
        let rawSave = root.toPlayerSave()
        var sanitized = PlayerSaveSanitizer.sanitize(rawSave)
        sanitized.schemaVersion = PlayerSave.currentSchemaVersion
        installObservedSave(sanitized)
        if loadedRoot.wasExisting {
            ensureRequiredGraph(rawSave: rawSave, sanitized: sanitized)
        } else if loadedRoot.initialSaveFailed {
            lastPersistenceError = .writeFailed
            isPersistenceDegraded = true
        }
    }

    isolated deinit {
        deferredSaveTask?.cancel()
    }

    public func performBatchMutation(
        _ update: (inout PlayerSave) -> Void,
        persistImmediately: Bool = true,
    ) throws {
        let mutationInterval = Self.performanceSignposter.beginInterval("PlayerSaveMutation")
        defer {
            Self.performanceSignposter.endInterval("PlayerSaveMutation", mutationInterval)
        }
        let snapshot = currentSave
        let (candidate, changedSlices) = try PlayerSaveSlice.prepareCandidate(from: snapshot, update: update)
        guard !changedSlices.isEmpty else { return }
        root.apply(candidate, slices: changedSlices, context: context)
        installObservedSave(candidate, slices: changedSlices)

        if persistImmediately {
            do {
                try saveGraph()
                clearPendingDeferredPersistence()
                lastPersistenceError = nil
            } catch {
                restoreSnapshot(snapshot)
                throw PlayerSavePersistenceError.writeFailed
            }
        } else {
            if pendingRollbackSnapshot == nil {
                pendingRollbackSnapshot = snapshot
            }
            pendingRollbackSlices.formUnion(changedSlices)
        }
    }

    @discardableResult
    public func persistBatch(
        logging message: String,
        _ mutation: (inout PlayerSave) -> Void,
    ) -> Bool {
        do {
            try performBatchMutation(mutation)
            return true
        } catch {
            logger.error(
                "\(message, privacy: .public): \(error.localizedDescription, privacy: .public)",
            )
            return false
        }
    }

    public func flushPendingPersistence() {
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        guard !pendingRollbackSlices.isEmpty else { return }
        do {
            try saveGraph()
            clearPendingDeferredPersistence()
            lastPersistenceError = nil
        } catch {
            rollbackPendingMutationIfNeeded()
        }
    }

    private func resetRoot(with save: PlayerSave) throws {
        let snapshot = currentSave
        let sanitized = PlayerSaveSanitizer.sanitize(save)
        root.update(from: sanitized, context: context)
        installObservedSave(sanitized)
        do {
            try saveGraph()
            clearPendingDeferredPersistence()
        } catch {
            restoreSnapshot(snapshot)
            throw error
        }
    }

    public func resetGameplayProgress() throws {
        try resetWithIncrementedSessionGeneration(.fresh)
    }

    public func applyTestSeed() throws {
        try resetWithIncrementedSessionGeneration(.testSeed)
    }

    public func unlockAllContent() throws {
        try resetWithIncrementedSessionGeneration(.unlockedAll)
    }

    private func resetWithIncrementedSessionGeneration(_ base: PlayerSave) throws {
        var save = base
        save.sessionGeneration = currentSave.sessionGeneration &+ 1
        try resetRoot(with: save)
    }

    private func mutate(_ update: (inout PlayerSave) -> Void) {
        do {
            try performBatchMutation(update, persistImmediately: persistSaveImmediately)
            if !persistSaveImmediately {
                scheduleDeferredSave()
            }
        } catch {
            lastPersistenceError = (error as? PlayerSavePersistenceError) ?? .writeFailed
        }
    }

    private func saveGraph() throws {
        let interval = Self.performanceSignposter.beginInterval("ModelContextSave")
        defer {
            Self.performanceSignposter.endInterval("ModelContextSave", interval)
        }
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
            logger.error("Failed to save SwiftData player graph: \(error.localizedDescription, privacy: .public)")
            throw PlayerSavePersistenceError.writeFailed
        }
    }

    private func ensureRequiredGraph(rawSave: PlayerSave? = nil, sanitized: PlayerSave? = nil) {
        let rawSave = rawSave ?? root.toPlayerSave()
        var save = sanitized ?? PlayerSaveSanitizer.sanitize(rawSave)
        save.schemaVersion = PlayerSave.currentSchemaVersion
        var repairSlices = root.repairSlices(for: save, currentSave: rawSave)
        guard !repairSlices.isEmpty else { return }

        if !repairSlices.contains(.root) {
            save.modifiedAt = Date()
            repairSlices.insert(.root)
        } else if save.modifiedAt == rawSave.modifiedAt {
            save.modifiedAt = Date()
        }

        let observedSnapshot = observedSave
        root.apply(save, slices: repairSlices, context: context)
        installObservedSave(save, slices: repairSlices)
        do {
            try saveGraph()
        } catch {
            restoreSnapshot(observedSnapshot)
        }
    }
}

#if DEBUG
public extension PlayerSaveStore {
    func dropInventoryGraphForTesting() {
        if let inventory = root.inventory {
            context.delete(inventory)
        }
        root.inventory = nil
    }

    func reapplyRequiredGraphForTesting() {
        ensureRequiredGraph()
    }
}
#endif

private extension PlayerSaveStore {
    static func openSaveContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        recoveryURL: URL?,
        logger: Logger,
    ) throws -> ModelContainerBootstrap.OpenResult {
        let interval = performanceSignposter.beginInterval("ModelContainerOpen")
        defer { performanceSignposter.endInterval("ModelContainerOpen", interval) }
        return try ModelContainerBootstrap.open(
            schema: schema,
            primaryConfiguration: configuration,
            logger: logger,
            logLabel: "player save",
            storeURLForRecovery: recoveryURL,
            deleteStoreOnFailure: true,
        )
    }

    static func loadOrCreateRoot(
        in context: ModelContext,
        logger: Logger,
    ) throws -> (root: PlayerSaveRoot, wasExisting: Bool, initialSaveFailed: Bool) {
        let interval = performanceSignposter.beginInterval("PlayerSaveRootLoad")
        defer {
            performanceSignposter.endInterval("PlayerSaveRootLoad", interval)
        }
        if let root = try PlayerSaveStoreConfiguration.fetchRoot(in: context, logger: logger) {
            return (root, true, false)
        }
        let root = PlayerSaveRoot(save: PlayerSaveSanitizer.sanitize(.fresh))
        context.insert(root)
        do {
            try context.save()
            return (root, false, false)
        } catch {
            logger.error(
                "Failed to save initial player save root: \(error.localizedDescription, privacy: .public)",
            )
            return (root, false, true)
        }
    }

    func scheduleDeferredSave() {
        deferredSaveTask?.cancel()
        deferredSaveTask = Task(priority: .utility) { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            do {
                try saveGraph()
                clearPendingDeferredPersistence()
                lastPersistenceError = nil
            } catch {
                rollbackPendingMutationIfNeeded()
            }
        }
    }

    func rollbackPendingMutationIfNeeded() {
        guard let pendingRollbackSnapshot else { return }
        restoreSnapshot(pendingRollbackSnapshot)
        clearPendingDeferredPersistence()
    }

    func restoreSnapshot(_ snapshot: PlayerSave) {
        root.update(from: snapshot, context: context)
        context.rollback()
        installObservedSave(snapshot)
    }

    func clearPendingDeferredPersistence() {
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        pendingRollbackSnapshot = nil
        pendingRollbackSlices = []
    }

    func installObservedSave(_ save: PlayerSave, slices: PlayerSaveSlice = .all) {
        if slices == .all {
            observedSave = save
            return
        }
        if slices.contains(.root) {
            observedSave.applyRootFields(from: save)
        }
        if slices.contains(.journey) {
            observedSave.journey = save.journey
        }
        if slices.contains(.roster) {
            observedSave.roster = save.roster
        }
        if slices.contains(.inventory) {
            observedSave.inventory = save.inventory
        }
        if slices.contains(.homestead) {
            observedSave.homestead = save.homestead
        }
        if slices.contains(.spires) {
            observedSave.spires = save.spires
        }
        if slices.contains(.labyrinth) {
            observedSave.labyrinth = save.labyrinth
        }
    }
}
