import Foundation
import os
import SwiftData
import TrinketContent

@MainActor
extension PlayerSaveStore {
    func performBatchMutation(
        _ update: (inout PlayerSave) -> Void,
    ) throws {
        try commit(proposedSave(by: update))
    }

    /// Single commit path shared by `performBatchMutation` (throws),
    /// `persistBatch` (Bool), and `persistTransaction` (tri-state): sanitize,
    /// diff slices, reconcile, write. The public spellings differ only in how
    /// they report failure.
    func commit(
        _ proposed: PlayerSave,
        accounting: SaveMutationAccounting = .receipts([]),
    ) throws {
        let mutationInterval = Self.performanceSignposter.beginInterval("PlayerSaveMutation")
        defer {
            Self.performanceSignposter.endInterval("PlayerSaveMutation", mutationInterval)
        }
        do {
            let snapshot = currentSave
            let (candidate, changedSlices) = try PlayerSaveSlice.prepareCandidate(from: snapshot, candidate: proposed)
            let receipts = accounting.receipts
            if let receipts {
                try SaveEconomicMutation.validate(from: snapshot, to: candidate, receipts: receipts)
            }
            try applyCandidate(
                candidate,
                replacing: snapshot,
                slices: changedSlices,
                receipts: receipts,
            )
        } catch {
            saveActionAttempt?.record(PlayerSavePersistenceError.mapped(error))
            throw error
        }
    }

    @discardableResult
    func persistBatch(
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
        let mapped = PlayerSavePersistenceError.mapped(error)
        saveActionAttempt?.record(mapped)
        lastPersistenceError = mapped
        logger.error(
            "\(message, privacy: .public): \(String(describing: error), privacy: .public)",
        )
    }

    /// Lifecycle/sync checkpoint for an already accepted recovery-file save.
    /// Gameplay commands always persist before publishing their candidate.
    public func flushPendingPersistence() {
        guard pendingSaveRecovery?.hasPendingSave == true else { return }
        do {
            try saveGraph()
        } catch {
            notePersistenceFailure(error, logging: "Failed to flush pending player progress")
        }
    }

    func saveGraph() throws {
        let save = root.toPlayerSave()
        try commitGraph(save, replacing: save, slices: [], cloudState: cloudDeviceState)
    }

    func applyCandidate(
        _ candidate: PlayerSave,
        replacing snapshot: PlayerSave,
        slices: PlayerSaveSlice,
        receipts: [SaveEconomicReceipt]? = nil,
    ) throws {
        guard !slices.isEmpty else { return }
        let state = try cloudStateRecordingMutation(from: snapshot, to: candidate, slices: slices, receipts: receipts)
        try commitGraph(candidate, replacing: snapshot, slices: slices, cloudState: state)
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
            memoryFallback: usesMemoryFallback,
            outboxRecords: { self.cloudOutbox?.storedRecords },
            primaryWrite: savePrimaryGraph,
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
}
