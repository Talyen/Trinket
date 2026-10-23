import Foundation
import os
import SwiftData
import TrinketContent

@MainActor
extension PlayerSaveStore {
    func performBatchMutation(_ update: (inout PlayerSave) -> Void) throws {
        let candidate = makeMutation()
        update(&candidate.save)
        try commit(candidate)
    }

    func makeMutation() -> SaveEconomicMutation {
        SaveEconomicMutation(currentSave, sourceRevision: commitRevision)
    }

    /// Every command commits against the revision it read before domain work.
    /// A nested command or reset must not be overwritten by an older candidate.
    func commit(
        _ proposed: SaveEconomicMutation,
        accounting: SaveMutationAccounting? = nil,
    ) throws {
        let mutationInterval = Self.performanceSignposter.beginInterval("PlayerSaveMutation")
        defer {
            Self.performanceSignposter.endInterval("PlayerSaveMutation", mutationInterval)
        }
        do {
            try requireCommitAdmission()
            guard proposed.sourceRevision == commitRevision else {
                throw PlayerSavePersistenceError.invalidSave("The save changed while preparing this action.")
            }
            let snapshot = currentSave
            let (candidate, changedSlices) = try PlayerSaveSlice.prepareCandidate(from: snapshot, candidate: proposed.save)
            let actions = try proposed.finalizedActions(at: candidate)
            let receipts = (accounting ?? .receipts(actions.isEmpty ? proposed.receipts : actions.map(\.receipt))).receipts
            if let receipts {
                try SaveEconomicMutation.validate(from: snapshot, to: candidate, receipts: receipts)
            }
            try applyCandidate(
                candidate,
                replacing: snapshot,
                slices: changedSlices,
                receipts: receipts,
                actions: actions.isEmpty ? nil : actions,
            )
        } catch {
            saveActionAttempt?.record(PlayerSavePersistenceError.mapped(error))
            throw error
        }
    }

    @discardableResult
    func persistBatch(logging message: String, _ mutation: (inout PlayerSave) -> Void) -> Bool {
        let candidate = makeMutation()
        mutation(&candidate.save)
        do {
            try commit(candidate)
            return true
        } catch {
            notePersistenceFailure(error, logging: message)
            return false
        }
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
        actions: [ResolvedSaveAction]? = nil,
    ) throws {
        guard !slices.isEmpty else { return }
        let state = try cloudStateRecordingMutation(from: snapshot, to: candidate, slices: slices, receipts: receipts, actions: actions)
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
            memoryFallback: usesMemoryFallback, labyrinthPayload: root.labyrinth?.mapPayload,
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
