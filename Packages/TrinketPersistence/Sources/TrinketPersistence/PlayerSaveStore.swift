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

    @ObservationIgnored var container: ModelContainer
    @ObservationIgnored var usesMemoryFallback: Bool
    @ObservationIgnored var context: ModelContext
    let recoveryConfiguration: ModelConfiguration?
    let pendingSaveRecovery: PendingSaveRecovery?
    var root: PlayerSaveRoot
    @ObservationIgnored var saveActionRetries: [String: Task<Void, Never>] = [:]
    public internal(set) var isRetryingSaveAction = false
    private var deferredSaveTask: Task<Void, Never>?
    private var pendingRollbackSnapshot: PlayerSave?
    private var pendingRollbackSlices: PlayerSaveSlice = []
    private var observedSave: PlayerSave = .fresh
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave",
    )

    public internal(set) var lastPersistenceError: PlayerSavePersistenceError?

    public var contentAccess: ContentAccessPolicy = .free

    public internal(set) var isPersistenceDegraded = false

    public private(set) var isCloudSyncEnabled: Bool
    public internal(set) var resetAffectsCloudProgress = false
    public private(set) var cloudSync: PlayerSaveCloudSync?
    @ObservationIgnored public var onExternalProgressChange: (@MainActor () -> Void)?
    @ObservationIgnored var cloudDeviceState = CloudDeviceState()
    var preservesUnreadableCloudState = false
    static let memoryFallbackError = PlayerSavePersistenceError.storeUnavailable(
        "Restoring progress on this device.",
    )

    #if DEBUG
    public var forcesNextSaveFailure = false
    public var forcesNextDatabaseSaveFailure = false
    #endif

    public var journey: JourneyProgressState {
        observedSave.journey
    }

    public var roster: PlayerRosterState {
        observedSave.roster
    }

    public var inventory: PlayerInventoryState {
        observedSave.inventory
    }

    public var homestead: PlayerHomesteadState {
        observedSave.homestead
    }

    public var spires: PlayerSpiresState {
        observedSave.spires
    }

    public var labyrinth: PlayerLabyrinthState {
        observedSave.labyrinth
    }

    public var contracts: PlayerContractsState {
        observedSave.contracts
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

    public convenience init(
        storeName: String? = nil,
        storeURL: URL? = nil,
        disableCloudSync: Bool = true,
        resetState: Bool = false,
        inMemoryOnly: Bool = false,
    ) throws {
        let bootstrapInterval = Self.performanceSignposter.beginInterval("PlayerSaveBootstrap")
        defer {
            Self.performanceSignposter.endInterval("PlayerSaveBootstrap", bootstrapInterval)
        }
        let requestedCloudSync = !disableCloudSync
            && !resetState
            && !inMemoryOnly
            && storeName == nil
            && storeURL == nil
        let schema = PlayerSaveGraph.schema
        let resolved = PlayerSaveStoreConfiguration.resolveStore(
            schema: schema,
            storeName: storeName,
            storeURL: storeURL,
            inMemoryOnly: inMemoryOnly,
        )

        if resetState, !inMemoryOnly {
            try PlayerSaveStoreConfiguration.cleanStoreFiles(at: resolved.finalURL)
        }
        let logger = Logger(subsystem: PlayerSaveDefaults.loggingSubsystem, category: "PlayerSave")
        let openResult = try Self.openSaveContainer(
            schema: schema,
            configuration: resolved.config,
            logger: logger,
        )
        try self.init(
            openResult: openResult,
            cloudSyncEnabled: requestedCloudSync,
            cloudTransport: requestedCloudSync ? CloudKitSaveTransport(containerIdentifier: Self.cloudKitContainerIdentifier) : nil,
            resetState: resetState,
            recoveryConfiguration: inMemoryOnly ? nil : resolved.config,
        )
    }

    init(
        openResult: ModelContainerBootstrap.OpenResult,
        cloudSyncEnabled: Bool,
        cloudTransport: (any CloudSaveTransport)? = nil,
        resetState: Bool = false,
        recoveryConfiguration: ModelConfiguration? = nil,
    ) throws {
        self.recoveryConfiguration = recoveryConfiguration
        pendingSaveRecovery = recoveryConfiguration.map { PendingSaveRecovery(storeURL: $0.url) }
        container = openResult.container
        usesMemoryFallback = openResult.usedInMemoryFallback
        isCloudSyncEnabled = cloudSyncEnabled && !openResult.usedInMemoryFallback
        if openResult.usedInMemoryFallback {
            isPersistenceDegraded = true
            lastPersistenceError = Self.memoryFallbackError
        }
        context = ModelContext(container)
        context.autosaveEnabled = false

        if resetState {
            try PlayerSaveStoreConfiguration.clearSaveRoot(in: context, logger: logger)
        }

        let loadedRoot = try Self.loadOrCreateRoot(
            in: context,
            isCloudSyncEnabled: cloudSyncEnabled && !openResult.usedInMemoryFallback,
            logger: logger,
        )
        root = loadedRoot.root
        do {
            try pendingSaveRecovery?.restore(
                into: root, context: context, preservesPrevious: !usesMemoryFallback && loadedRoot.wasExisting,
            )
        } catch {
            // PersistenceCheck: allow - record is preserved aside when possible; retry persists newer progress
            try? pendingSaveRecovery?.moveCorruptAside()
            logger.error(
                "Pending save could not be read; continuing with readable progress: \(String(describing: error), privacy: .public)",
            )
            isPersistenceDegraded = true
        }
        do {
            cloudDeviceState = try CloudDeviceState.decode(root.cloudStatePayload)
            resetAffectsCloudProgress = cloudDeviceState.activeAccountID != nil
        } catch {
            preservesUnreadableCloudState = true
            isCloudSyncEnabled = false
            logger.error("iCloud metadata could not be read; keeping progress local: \(String(describing: error), privacy: .public)")
        }
        let rawSave = root.toPlayerSave()
        guard rawSave.schemaVersion == PlayerSave.currentSchemaVersion else {
            throw PlayerSavePersistenceError.invalidSave("Unsupported save schema version.")
        }
        var sanitized = PlayerSaveSanitizer.sanitize(rawSave)
        sanitized.schemaVersion = PlayerSave.currentSchemaVersion
        installObservedSave(sanitized)
        if loadedRoot.wasExisting {
            ensureRequiredGraph(rawSave: rawSave, sanitized: sanitized)
        } else if loadedRoot.initialSaveFailed {
            lastPersistenceError = .writeFailed
            isPersistenceDegraded = true
        }
        if pendingSaveRecovery?.hasPendingSave == true {
            do { try saveGraph() } catch { scheduleRecoveryRetry() }
        }
        if isCloudSyncEnabled, let cloudTransport {
            cloudSync = PlayerSaveCloudSync(store: self, transport: cloudTransport)
        }
    }

    isolated deinit {
        deferredSaveTask?.cancel()
        for task in saveActionRetries.values {
            task.cancel()
        }
    }

    public func performBatchMutation(
        _ update: (inout PlayerSave) -> Void,
        persistImmediately: Bool = true,
    ) throws {
        try commitCandidate(proposedSave(by: update), persistImmediately: persistImmediately)
    }

    private func commitCandidate(_ proposed: PlayerSave, persistImmediately: Bool = true) throws {
        let mutationInterval = Self.performanceSignposter.beginInterval("PlayerSaveMutation")
        defer {
            Self.performanceSignposter.endInterval("PlayerSaveMutation", mutationInterval)
        }
        let snapshot = currentSave
        let (candidate, changedSlices) = try PlayerSaveSlice.prepareCandidate(from: snapshot, candidate: proposed)
        try applyCandidate(candidate, replacing: snapshot, slices: changedSlices, persistImmediately: persistImmediately)
    }

    @discardableResult
    public func persistBatch(
        logging message: String,
        _ mutation: (inout PlayerSave) -> Void,
    ) -> Bool {
        persistCandidate(proposedSave(by: mutation), logging: message)
    }

    private func proposedSave(by mutation: (inout PlayerSave) -> Void) -> PlayerSave {
        var candidate = currentSave
        mutation(&candidate)
        return candidate
    }

    func persistCandidate(_ candidate: PlayerSave, logging message: String) -> Bool {
        do {
            try commitCandidate(candidate)
            return true
        } catch {
            lastPersistenceError = (error as? PlayerSavePersistenceError) ?? .writeFailed
            logger.error(
                "\(message, privacy: .public): \(String(describing: error), privacy: .public)",
            )
            return false
        }
    }

    public func flushPendingPersistence() {
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        guard !pendingRollbackSlices.isEmpty || pendingSaveRecovery?.hasPendingSave == true else { return }
        do {
            try saveGraph()
            clearPendingDeferredPersistence()
        } catch {
            rollbackPendingMutationIfNeeded()
        }
    }

    func saveGraph() throws {
        let interval = Self.performanceSignposter.beginInterval("ModelContextSave")
        defer {
            Self.performanceSignposter.endInterval("ModelContextSave", interval)
        }
        do {
            if !preservesUnreadableCloudState {
                root.cloudStatePayload = try JSONEncoder().encode(cloudDeviceState)
            }
            #if DEBUG
            if forcesNextSaveFailure {
                forcesNextSaveFailure = false
                throw NSError(domain: "PlayerSaveStoreTests", code: 1)
            }
            #endif
            try saveGraphWithRecovery()
            isPersistenceDegraded = usesMemoryFallback || pendingSaveRecovery?.hasPendingSave == true
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = .writeFailed
            logger.error("Failed to save SwiftData player graph: \(error.localizedDescription, privacy: .public)")
            throw PlayerSavePersistenceError.writeFailed
        }
    }

    func restoreCloudMetadata(_ state: CloudDeviceState) throws {
        cloudDeviceState = state
        root.cloudStatePayload = try JSONEncoder().encode(state)
    }

    func applyCandidate(
        _ candidate: PlayerSave,
        replacing snapshot: PlayerSave,
        slices: PlayerSaveSlice,
        persistImmediately: Bool = true,
    ) throws {
        guard !slices.isEmpty else { return }
        root.apply(candidate, slices: slices, context: context)
        if persistImmediately {
            do {
                try saveGraph()
                clearPendingDeferredPersistence()
            } catch {
                compensate(snapshot: snapshot, slices: slices)
                throw PlayerSavePersistenceError.writeFailed
            }
        } else {
            if pendingRollbackSnapshot == nil {
                pendingRollbackSnapshot = snapshot
            }
            pendingRollbackSlices.formUnion(slices)
            scheduleDeferredSave()
        }
        installObservedSave(candidate, slices: slices)
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

        do {
            try applyCandidate(save, replacing: observedSave, slices: repairSlices)
        } catch {
            logger.error("Failed to repair player save graph: \(String(describing: error), privacy: .public)")
            lastPersistenceError = .writeFailed
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

extension PlayerSaveStore {
    func saveGraphWithRecovery() throws {
        guard let pendingSaveRecovery else {
            try savePrimaryGraph()
            return
        }
        if try pendingSaveRecovery.persist(
            save: root.toPlayerSave(), cloudState: root.cloudStatePayload,
            memoryFallback: usesMemoryFallback, primaryWrite: savePrimaryGraph,
        ) {
            scheduleRecoveryRetry()
        }
    }

    func scheduleRecoveryRetry() {
        guard !usesMemoryFallback else { return }
        pendingSaveRecovery?.retryInBackground { [weak self] in
            guard let self else { return true }
            do { try saveGraph() } catch { return false }
            return pendingSaveRecovery?.hasPendingSave != true
        }
    }

    static func openSaveContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        logger: Logger,
    ) throws -> ModelContainerBootstrap.OpenResult {
        let interval = performanceSignposter.beginInterval("ModelContainerOpen")
        defer { performanceSignposter.endInterval("ModelContainerOpen", interval) }
        return try ModelContainerBootstrap.open(
            schema: schema,
            primaryConfiguration: configuration,
            logger: logger,
            logLabel: "player save",
        )
    }

    static func loadOrCreateRoot(
        in context: ModelContext,
        isCloudSyncEnabled: Bool,
        logger: Logger,
    ) throws -> (root: PlayerSaveRoot, wasExisting: Bool, initialSaveFailed: Bool) {
        let interval = performanceSignposter.beginInterval("PlayerSaveRootLoad")
        defer {
            performanceSignposter.endInterval("PlayerSaveRootLoad", interval)
        }
        if let root = try PlayerSaveStoreConfiguration.fetchRoot(
            in: context,
            isCloudSyncEnabled: isCloudSyncEnabled,
            logger: logger,
        ) {
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
            } catch {
                rollbackPendingMutationIfNeeded()
            }
        }
    }

    func rollbackPendingMutationIfNeeded() {
        guard let pendingRollbackSnapshot else { return }
        restoreSnapshot(pendingRollbackSnapshot, slices: pendingRollbackSlices)
        clearPendingDeferredPersistence()
    }

    func restoreSnapshot(_ snapshot: PlayerSave, slices: PlayerSaveSlice = .all) {
        root.apply(snapshot, slices: slices, context: context)
        installObservedSave(snapshot, slices: slices)
    }

    func clearPendingDeferredPersistence() {
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        pendingRollbackSnapshot = nil
        pendingRollbackSlices = []
    }

    func installObservedSave(_ save: PlayerSave, slices: PlayerSaveSlice = .all) {
        if save.sessionGeneration != observedSave.sessionGeneration {
            for task in saveActionRetries.values {
                task.cancel()
            }
            saveActionRetries.removeAll()
            isRetryingSaveAction = false
        }
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
        if slices.contains(.contracts) {
            observedSave.contracts = save.contracts
        }
    }
}
