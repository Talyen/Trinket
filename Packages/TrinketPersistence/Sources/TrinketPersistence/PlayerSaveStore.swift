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

    /// `true` when a corrupt on-disk store was deleted and replaced with a fresh container.
    public private(set) var recoveredAfterStoreDeletion = false

    #if DEBUG
    public var forcesNextSaveFailure = false
    #endif

    public var journey: JourneyProgressState {
        get { root.journey?.toJourneyProgressState() ?? .initial }
        set { mutate { $0.journey = PlayerSaveSanitizer.sanitizeJourney(newValue) } }
    }

    public var roster: PlayerRosterState {
        get {
            let inventory = root.inventory?.toPlayerInventoryState() ?? .freshStart
            return root.roster?.toPlayerRosterState(inventory: inventory) ?? .freshStart
        }
        set { mutate { $0.roster = newValue } }
    }

    public var inventory: PlayerInventoryState {
        get { root.inventory?.toPlayerInventoryState() ?? .freshStart }
        set { mutate { $0.inventory = newValue } }
    }

    public var homestead: PlayerHomesteadState {
        get { root.homestead?.toPlayerHomesteadState() ?? .freshStart }
        set { mutate { $0.homestead = newValue } }
    }

    public var spires: PlayerSpiresState {
        get { root.spires?.toPlayerSpiresState() ?? .freshStart }
        set { mutate { $0.spires = PlayerSaveSanitizer.sanitizeSpires(newValue) } }
    }

    public var labyrinth: PlayerLabyrinthState {
        get { root.labyrinth?.toPlayerLabyrinthState() ?? .freshStart }
        set { mutate { $0.labyrinth = PlayerSaveSanitizer.sanitizeLabyrinth(newValue) } }
    }

    public var currentSave: PlayerSave {
        root.toPlayerSave()
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
        self.persistSaveImmediately = persistSaveImmediately
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

        let openResult = try ModelContainerBootstrap.open(
            schema: schema,
            primaryConfiguration: resolved.config,
            logger: logger,
            logLabel: "player save",
            storeURLForRecovery: resolved.recoveryURL,
            deleteStoreOnFailure: !inMemoryOnly
        )
        container = openResult.container
        recoveredAfterStoreDeletion = openResult.recoveredAfterStoreDeletion
        if openResult.usedInMemoryFallback {
            isPersistenceDegraded = true
            lastPersistenceError = .storeUnavailable(
                "Couldn't open on-device save storage. Progress is kept in memory until you restart after freeing space."
            )
        } else if openResult.recoveredAfterStoreDeletion {
            lastPersistenceError = .storeUnavailable(
                "Saved progress on this device was damaged and had to be reset. Previous progress could not be recovered."
            )
        }
        context = ModelContext(container)
        context.autosaveEnabled = false

        if resetState {
            try PlayerSaveStoreConfiguration.clearSaveRoot(in: context, logger: logger)
        }

        if let existingRoot = try PlayerSaveStoreConfiguration.fetchRoot(in: context, logger: logger) {
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

    // Concurrency-Safety: isolated deinit runs on MainActor so cancelling the
    // deferred save Task does not touch MainActor-isolated state from a nonisolated deinit.
    isolated deinit {
        deferredSaveTask?.cancel()
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
        } else if pendingRollbackSnapshot == nil {
            // Keep the last persisted snapshot across coalesced deferred mutations so a
            // failed flush rolls back past every unsaved change, not only the latest one.
            pendingRollbackSnapshot = snapshot
        }
    }

    /// Writes any coalesced deferred mutation immediately (no yield). Call from
    /// scene-phase teardown so progress is durable before suspension.
    public func flushPendingPersistence() {
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

    public func flushPendingSave() async {
        await Task.yield()
        flushPendingPersistence()
    }

    private func scheduleDeferredSave() {
        deferredSaveTask?.cancel()
        deferredSaveTask = Task(priority: .utility) { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            do {
                try saveGraph()
                pendingRollbackSnapshot = nil
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

    private func rollbackPendingMutationIfNeeded() {
        guard let pendingRollbackSnapshot else { return }
        root.update(from: pendingRollbackSnapshot)
        self.pendingRollbackSnapshot = nil
    }

    private func resetRoot(with save: PlayerSave) throws {
        // Update the existing primary root in place. Delete+insert after a swallowed
        // clear failure left duplicate `id == "primary"` rows so a later cold start
        // could reload stale progress instead of the reset snapshot.
        root.update(from: PlayerSaveSanitizer.sanitize(save))
        try saveGraph()
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
}
