import Foundation
import Observation
import os
import SwiftData
import TrinketContent

/// Write-through hub for the player SwiftData graph.
///
/// **Owns:** `ModelContainer` / `ModelContext`, deferred save + rollback,
/// reset/seed, and slice property setters that sanitize then persist.
///
/// **Does not own:** cross-slice player actions — use `PlayerHomesteadStore`
/// (`homesteadStore.buildOrUpgradeNode`). Pure rules stay on value types
/// (`PlayerHomesteadState`, `PlayerRosterState`, …). Prefer slice properties
/// (`journey` / `roster` / `inventory` / `homestead`) for single-slice reads
/// and writes; do not add empty pass-through facades.
///
/// **Where to put new persistence code:**
/// 1. Pure domain rules → value types under `Models/`
/// 2. Cross-slice player actions → `PlayerHomesteadStore` (or a real action type)
/// 3. Container open / URL / CloudKit config → `PlayerSaveStoreConfiguration`
/// 4. Only add methods here when they are hub infrastructure (save, rollback, reset)
@MainActor
@Observable
public final class PlayerSaveStore {
    public static let cloudKitContainerIdentifier = "iCloud.com.ryanmcintire.Trinket"
    private static let performanceSignposter = OSSignposter(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PersistencePerformance"
    )

    private let container: ModelContainer
    private let context: ModelContext
    private var root: PlayerSaveRoot
    private var deferredSaveTask: Task<Void, Never>?
    private var pendingRollbackSnapshot: PlayerSave?
    private var pendingRollbackSlices: PlayerSaveSlice = []
    private var observedJourney = JourneyProgressState.initial
    private var observedRoster = PlayerRosterState.freshStart
    private var observedInventory = PlayerInventoryState.freshStart
    private var observedHomestead = PlayerHomesteadState.freshStart
    private var observedSpires = PlayerSpiresState.freshStart
    private var observedLabyrinth = PlayerLabyrinthState.freshStart
    private var observedSchemaVersion = PlayerSave.currentSchemaVersion
    private var observedModifiedAt = Date.distantPast
    private var observedSessionGeneration: UInt64 = 0
    private var observedCorruptionAltarCooldownRemaining = 0
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave"
    )

    public private(set) var lastPersistenceError: PlayerSavePersistenceError?

    /// `true` when disk store failed and an in-memory fallback container is active.
    public private(set) var isPersistenceDegraded = false
    public let isCloudSyncEnabled: Bool

    #if DEBUG
    public var forcesNextSaveFailure = false
    #endif

    public var journey: JourneyProgressState {
        get { observedJourney }
        set { mutate { $0.journey = PlayerSaveSanitizer.sanitizeJourney(newValue) } }
    }

    public var roster: PlayerRosterState {
        get { observedRoster }
        set { mutate { $0.roster = newValue } }
    }

    public var inventory: PlayerInventoryState {
        get { observedInventory }
        set { mutate { $0.inventory = newValue } }
    }

    public var homestead: PlayerHomesteadState {
        get { observedHomestead }
        set { mutate { $0.homestead = newValue } }
    }

    public var spires: PlayerSpiresState {
        get { observedSpires }
        set { mutate { $0.spires = PlayerSaveSanitizer.sanitizeSpires(newValue) } }
    }

    public var labyrinth: PlayerLabyrinthState {
        get { observedLabyrinth }
        set { mutate { $0.labyrinth = newValue } }
    }

    /// Root-level Corruption Altar cooldown — prefer this over `currentSave` for reads.
    public var corruptionAltarCooldownRemaining: Int {
        observedCorruptionAltarCooldownRemaining
    }

    public var currentSave: PlayerSave {
        assembledSave()
    }

    /// Cross-slice homestead actions — prefer over growing this hub.
    public var homesteadStore: PlayerHomesteadStore {
        PlayerHomesteadStore(save: self)
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
        let bootstrapInterval = Self.performanceSignposter.beginInterval("PlayerSaveBootstrap")
        defer {
            Self.performanceSignposter.endInterval("PlayerSaveBootstrap", bootstrapInterval)
        }
        self.persistSaveImmediately = persistSaveImmediately
        let requestedCloudSync = !disableCloudSync
            && !inMemoryOnly
            && storeName == nil
            && storeURL == nil
        let finalURL = PlayerSaveStoreConfiguration.resolveStoreURL(storeName: storeName, storeURL: storeURL)

        if resetState, !inMemoryOnly {
            PlayerSaveStoreConfiguration.cleanStoreFiles(at: finalURL)
        }

        let schema = PlayerSaveGraph.schema
        let resolved = PlayerSaveStoreConfiguration.resolveConfiguration(
            schema: schema,
            finalURL: finalURL,
            storeName: storeName,
            storeURL: storeURL,
            disableCloudSync: disableCloudSync,
            inMemoryOnly: inMemoryOnly,
            cloudKitContainerIdentifier: Self.cloudKitContainerIdentifier
        )

        let openResult = try Self.openContainer(
            schema: schema,
            configuration: resolved.config,
            recoveryURL: resolved.recoveryURL,
            logger: logger
        )
        container = openResult.container
        isCloudSyncEnabled = requestedCloudSync && !openResult.usedInMemoryFallback
        if openResult.usedInMemoryFallback {
            isPersistenceDegraded = true
            lastPersistenceError = .storeUnavailable(
                "Couldn't open on-device save storage. Progress is kept in memory until you restart after freeing space."
            )
        }
        context = ModelContext(container)
        context.autosaveEnabled = false

        if resetState {
            try PlayerSaveStoreConfiguration.clearSaveRoot(in: context, logger: logger)
        }

        let loadedRoot = try Self.loadOrCreateRoot(in: context, logger: logger)
        root = loadedRoot.root
        installObservedSave(root.toPlayerSave())
        if loadedRoot.wasExisting {
            ensureRequiredGraph()
        } else if loadedRoot.initialSaveFailed {
            lastPersistenceError = .writeFailed
            isPersistenceDegraded = true
        }
    }

    // Concurrency-Safety: isolated deinit runs on MainActor so cancelling the
    // deferred save Task does not touch MainActor-isolated state from a nonisolated deinit.
    isolated deinit {
        deferredSaveTask?.cancel()
    }

    public func performBatchMutation(
        _ update: (inout PlayerSave) -> Void,
        persistImmediately: Bool = true
    ) throws {
        let mutationInterval = Self.performanceSignposter.beginInterval("PlayerSaveMutation")
        defer {
            Self.performanceSignposter.endInterval("PlayerSaveMutation", mutationInterval)
        }
        let snapshot = measured("SnapshotProjection") { currentSave }
        let (candidate, changedSlices) = try measured("MutationPreparation") {
            var candidate = snapshot
            update(&candidate)
            var changedSlices = PlayerSaveSlice.changed(between: snapshot, and: candidate)
            candidate = PlayerSaveSanitizer.sanitize(candidate, changedSlices: changedSlices)
            // The roster sanitizer resolves loadouts against the sanitized inventory, so an
            // inventory-only mutation can still rewrite the roster; persist that fix too.
            if changedSlices.contains(.inventory), snapshot.roster != candidate.roster {
                changedSlices.insert(.roster)
            }
            try PlayerSaveSanitizer.validate(candidate)
            if !changedSlices.isEmpty {
                candidate.modifiedAt = Date()
                changedSlices.insert(.root)
            }
            return (candidate, changedSlices)
        }
        guard !changedSlices.isEmpty else { return }
        measured("GraphApply") {
            root.apply(candidate, slices: changedSlices, context: context)
            installObservedSave(candidate, slices: changedSlices)
        }

        if persistImmediately {
            do {
                try saveGraph()
                clearPendingDeferredPersistence()
                lastPersistenceError = nil
            } catch {
                root.apply(snapshot, slices: changedSlices, context: context)
                installObservedSave(snapshot, slices: changedSlices)
                lastPersistenceError = .writeFailed
                logger.error("Failed to save SwiftData player graph: \(error.localizedDescription, privacy: .public)")
                throw PlayerSavePersistenceError.writeFailed
            }
        } else {
            if pendingRollbackSnapshot == nil {
                // Keep the last persisted snapshot across coalesced deferred mutations so a
                // failed flush rolls back past every unsaved change, not only the latest one.
                pendingRollbackSnapshot = snapshot
            }
            pendingRollbackSlices.formUnion(changedSlices)
        }
    }

    /// Persists a batch mutation, returning `false` (with a logged message) on failure.
    ///
    /// Callers keep their own failure bookkeeping (mark-failed, keep the session
    /// open, play SFX) so they never clear progress that failed to persist.
    @discardableResult
    public func persistBatch(
        logging message: String,
        _ mutation: (inout PlayerSave) -> Void
    ) -> Bool {
        do {
            try performBatchMutation(mutation)
            return true
        } catch {
            logger.error(
                "\(message, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    /// Writes any coalesced deferred mutation immediately (no yield). Call from
    /// scene-phase teardown so progress is durable before suspension.
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
            lastPersistenceError = .writeFailed
            logger.error("Failed to flush deferred SwiftData save: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resetRoot(with save: PlayerSave) throws {
        // Update the existing primary root in place. Delete+insert after a swallowed
        // clear failure left duplicate `id == "primary"` rows so a later cold start
        // could reload stale progress instead of the reset snapshot.
        let snapshot = currentSave
        let sanitized = PlayerSaveSanitizer.sanitize(save)
        root.update(from: sanitized, context: context)
        installObservedSave(sanitized)
        do {
            try saveGraph()
            clearPendingDeferredPersistence()
        } catch {
            root.update(from: snapshot, context: context)
            installObservedSave(snapshot)
            throw error
        }
    }

    public func resetGameplayProgress() throws {
        var fresh = PlayerSave.fresh
        fresh.sessionGeneration = currentSave.sessionGeneration &+ 1
        try resetRoot(with: fresh)
    }

    public func applyTestSeed() throws {
        try resetRoot(with: .testSeed)
    }

    /// Unlocks all heroes/companions at level 20 and clears Chapter 1 (Modes unlock).
    public func unlockAllContent() throws {
        var unlocked = PlayerSave.unlockedAll
        unlocked.sessionGeneration = currentSave.sessionGeneration &+ 1
        try resetRoot(with: unlocked)
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
            throw PlayerSavePersistenceError.writeFailed
        }
    }

    private func ensureRequiredGraph() {
        var save = currentSave
        save = PlayerSaveSanitizer.sanitize(save)
        root.update(from: save, context: context)
        installObservedSave(save)
        do {
            try context.save()
        } catch {
            lastPersistenceError = .writeFailed
            logger.error(
                "Failed to persist sanitized player graph: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func openContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        recoveryURL: URL?,
        logger: Logger
    ) throws -> ModelContainerBootstrap.OpenResult {
        let interval = performanceSignposter.beginInterval("ModelContainerOpen")
        defer {
            performanceSignposter.endInterval("ModelContainerOpen", interval)
        }
        return try ModelContainerBootstrap.open(
            schema: schema,
            primaryConfiguration: configuration,
            logger: logger,
            logLabel: "player save",
            storeURLForRecovery: recoveryURL,
            deleteStoreOnFailure: true
        )
    }

    private static func loadOrCreateRoot(
        in context: ModelContext,
        logger: Logger
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
                "Failed to save initial player save root: \(error.localizedDescription, privacy: .public)"
            )
            return (root, false, true)
        }
    }

    private func measured<Result>(
        _ name: StaticString,
        operation: () throws -> Result
    ) rethrows -> Result {
        let interval = Self.performanceSignposter.beginInterval(name)
        defer {
            Self.performanceSignposter.endInterval(name, interval)
        }
        return try operation()
    }
}

private extension PlayerSaveStore {
    func scheduleDeferredSave() {
        deferredSaveTask?.cancel()
        deferredSaveTask = Task(priority: .utility) { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            do {
                try saveGraph()
                clearPendingDeferredPersistence()
                lastPersistenceError = nil
            } catch {
                rollbackPendingMutationIfNeeded()
                lastPersistenceError = .writeFailed
                logger.error(
                    "Failed to persist deferred player graph mutation: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    func rollbackPendingMutationIfNeeded() {
        guard let pendingRollbackSnapshot else { return }
        root.apply(pendingRollbackSnapshot, slices: pendingRollbackSlices, context: context)
        installObservedSave(pendingRollbackSnapshot, slices: pendingRollbackSlices)
        clearPendingDeferredPersistence()
    }

    func clearPendingDeferredPersistence() {
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        pendingRollbackSnapshot = nil
        pendingRollbackSlices = []
    }

    func assembledSave() -> PlayerSave {
        PlayerSave(
            schemaVersion: observedSchemaVersion,
            modifiedAt: observedModifiedAt,
            sessionGeneration: observedSessionGeneration,
            journey: observedJourney,
            roster: observedRoster,
            inventory: observedInventory,
            homestead: observedHomestead,
            spires: observedSpires,
            labyrinth: observedLabyrinth,
            corruptionAltarCooldownRemaining: observedCorruptionAltarCooldownRemaining
        )
    }

    func installObservedSave(_ save: PlayerSave, slices: PlayerSaveSlice = .all) {
        if slices.contains(.root) {
            observedSchemaVersion = save.schemaVersion
            observedModifiedAt = save.modifiedAt
            observedSessionGeneration = save.sessionGeneration
            observedCorruptionAltarCooldownRemaining = save.corruptionAltarCooldownRemaining
        }
        if slices.contains(.journey) {
            observedJourney = save.journey
        }
        if slices.contains(.roster) {
            observedRoster = save.roster
        }
        if slices.contains(.inventory) {
            observedInventory = save.inventory
        }
        if slices.contains(.homestead) {
            observedHomestead = save.homestead
        }
        if slices.contains(.spires) {
            observedSpires = save.spires
        }
        if slices.contains(.labyrinth) {
            observedLabyrinth = save.labyrinth
        }
    }
}
