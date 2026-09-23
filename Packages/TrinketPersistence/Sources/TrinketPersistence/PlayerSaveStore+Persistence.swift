import Foundation
import os
import SwiftData
import TrinketContent

struct PendingDeferredSave {
    let rollbackSnapshot: PlayerSave
    private(set) var slices: PlayerSaveSlice

    init(snapshot: PlayerSave, slices: PlayerSaveSlice) {
        rollbackSnapshot = snapshot
        self.slices = slices
    }

    mutating func include(_ slices: PlayerSaveSlice) {
        self.slices.formUnion(slices)
    }
}

@MainActor
extension PlayerSaveStore {
    public func performBatchMutation(
        _ update: (inout PlayerSave) -> Void,
        persistImmediately: Bool = true,
    ) throws {
        try commit(proposedSave(by: update), persistImmediately: persistImmediately)
    }

    /// Single commit path shared by `performBatchMutation` (throws),
    /// `persistBatch` (Bool), and `persistTransaction` (tri-state): sanitize,
    /// diff slices, reconcile, write. The public spellings differ only in how
    /// they report failure.
    func commit(_ proposed: PlayerSave, persistImmediately: Bool = true) throws {
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
        do {
            try commit(proposedSave(by: mutation))
            return true
        } catch {
            notePersistenceFailure(error, logging: message)
            return false
        }
    }

    private func proposedSave(by mutation: (inout PlayerSave) -> Void) -> PlayerSave {
        var candidate = currentSave
        mutation(&candidate)
        return candidate
    }

    func proposedSave<Value, Failure: Error>(
        by mutation: (inout PlayerSave) -> Result<Value, Failure>,
    ) -> (candidate: PlayerSave, result: Result<Value, Failure>) {
        var candidate = currentSave
        let result = mutation(&candidate)
        return (candidate, result)
    }

    /// Single mapping from commit errors to `lastPersistenceError` + log.
    /// All persist spellings (`persistBatch`, `persistTransaction`) share this so
    /// failures stay diagnosable in one place. Typed errors pass through;
    /// see `PlayerSavePersistenceError.mapped`.
    func notePersistenceFailure(_ error: Error, logging message: String) {
        lastPersistenceError = PlayerSavePersistenceError.mapped(error)
        logger.error(
            "\(message, privacy: .public): \(String(describing: error), privacy: .public)",
        )
    }

    public func flushPendingPersistence() {
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        guard pendingDeferredSave != nil || pendingSaveRecovery?.hasPendingSave == true else { return }
        persistDeferredSave(logging: "Failed to flush deferred player progress")
    }

    private func persistDeferredSave(logging message: String) {
        do {
            try saveGraph()
            clearPendingDeferredPersistence()
        } catch {
            notePersistenceFailure(error, logging: message)
            rollbackPendingMutationIfNeeded()
        }
    }

    func saveGraph() throws {
        let interval = Self.performanceSignposter.beginInterval("ModelContextSave")
        defer {
            Self.performanceSignposter.endInterval("ModelContextSave", interval)
        }
        do {
            try encodeCloudStateForSave()
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
            notePersistenceFailure(error, logging: "Failed to save SwiftData player graph")
            throw PlayerSavePersistenceError.mapped(error)
        }
    }

    /// Encodes local cloud metadata onto the graph before a durable write.
    /// Shared by normal commits and durable resets.
    func encodeCloudStateForSave() throws {
        try setCloudDeviceState(cloudDeviceState)
    }

    /// Single writer for `root.cloudStatePayload` outside recovery restore.
    /// Keeps unreadable payloads opaque when `preservesUnreadableCloudState`.
    func setCloudDeviceState(_ state: CloudDeviceState) throws {
        cloudDeviceState = state
        if !preservesUnreadableCloudState {
            root.cloudStatePayload = try JSONEncoder().encode(state)
        }
    }

    func restoreCloudMetadata(_ state: CloudDeviceState) throws {
        try setCloudDeviceState(state)
    }

    func applyCandidate(
        _ candidate: PlayerSave,
        replacing snapshot: PlayerSave,
        slices: PlayerSaveSlice,
        persistImmediately: Bool = true,
        recordsCloudMutation: Bool = true,
    ) throws {
        guard !slices.isEmpty else { return }
        let previousCloudState = cloudDeviceState
        if recordsCloudMutation, persistImmediately {
            try recordCloudMutation(from: snapshot, to: candidate, slices: slices)
        }
        root.apply(candidate, slices: slices, context: context)
        if persistImmediately {
            do {
                try saveGraph()
                // Immediate success persists the whole graph, including any
                // earlier deferred rows, so the deferred rollback is done.
                clearPendingDeferredPersistence()
            } catch {
                do {
                    try restoreCloudMetadata(previousCloudState)
                } catch {
                    logger.error("Failed to restore cloud journal after a rejected save: \(String(describing: error), privacy: .public)")
                }
                // Immediate total failure preserves earlier deferred changes
                // per the storage contract: compensate only this attempt's
                // slices, leaving deferred increments published for their own
                // flush/rollback.
                restoreSnapshot(snapshot, slices: slices)
                throw PlayerSavePersistenceError.mapped(error)
            }
        } else {
            if pendingDeferredSave == nil {
                pendingDeferredSave = PendingDeferredSave(snapshot: snapshot, slices: slices)
            } else {
                pendingDeferredSave?.include(slices)
            }
            scheduleDeferredSave()
        }
        installObservedSave(candidate, slices: slices)
    }
}

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

    func scheduleDeferredSave() {
        deferredSaveTask?.cancel()
        deferredSaveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            persistDeferredSave(logging: "Failed deferred player progress save")
        }
    }

    func rollbackPendingMutationIfNeeded() {
        guard let pendingDeferredSave else { return }
        restoreSnapshot(pendingDeferredSave.rollbackSnapshot, slices: pendingDeferredSave.slices)
        clearPendingDeferredPersistence()
    }

    func restoreSnapshot(_ snapshot: PlayerSave, slices: PlayerSaveSlice = .all) {
        root.apply(snapshot, slices: slices, context: context)
        installObservedSave(snapshot, slices: slices)
    }

    func clearPendingDeferredPersistence() {
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        pendingDeferredSave = nil
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
        var updated = observedSave
        for section in slices.sections {
            section.copy(from: save, into: &updated)
        }
        observedSave = updated
    }
}
