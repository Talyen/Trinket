import Foundation
import os
import SwiftData

enum SaveGraphDurability {
    case recoverable
    case primaryOnly
}

@MainActor
extension PlayerSaveStore {
    /// Observation callbacks run synchronously, including during slice publication.
    /// They may request a retry, but cannot enter a partially published commit.
    func requireCommitAdmission() throws {
        guard !isCommittingGraph else {
            throw PlayerSavePersistenceError.storeUnavailable("A player-save commit is still publishing.")
        }
    }

    /// One publication boundary for gameplay, cloud transitions and resets.
    /// Cloud encoding precedes graph mutation; compensation uses captured payloads
    /// and never performs another fallible serialization of the old outbox.
    func commitGraph(
        _ candidate: PlayerSave,
        replacing snapshot: PlayerSave,
        slices: PlayerSaveSlice,
        cloudState: CloudDeviceState,
        durability: SaveGraphDurability = .recoverable,
    ) throws {
        try requireCommitAdmission()
        isCommittingGraph = true
        defer { isCommittingGraph = false }
        let interval = Self.performanceSignposter.beginInterval("ModelContextSave")
        defer { Self.performanceSignposter.endInterval("ModelContextSave", interval) }
        do {
            let graphWrite = try PlayerSaveGraphWrite(save: candidate, slices: slices)
            let compensation = PlayerSaveGraphWrite(restoring: snapshot, slices: slices, root: root)
            let update: CloudSaveOutbox.Update?
            if preservesUnreadableCloudState {
                update = nil
            } else {
                guard let cloudOutbox else { throw CloudSaveError.unavailable }
                update = try cloudOutbox.prepare(cloudState)
            }
            let previousPayload = root.cloudStatePayload
            if let update {
                cloudOutbox?.apply(update)
                root.cloudStatePayload = update.metadata
            }
            root.apply(graphWrite, context: context)
            do {
                #if DEBUG
                if forcesNextSaveFailure {
                    forcesNextSaveFailure = false
                    throw PlayerSavePersistenceError.writeFailed
                }
                #endif
                switch durability {
                case .recoverable:
                    try saveGraphWithRecovery()
                    isPersistenceDegraded = usesMemoryFallback || pendingSaveRecovery?.hasPendingSave == true
                    lastPersistenceError = nil
                case .primaryOnly:
                    try savePrimaryGraph()
                    alignRecoveryAfterReset(candidate)
                }
            } catch {
                if let update {
                    cloudOutbox?.compensate(update)
                }
                root.cloudStatePayload = previousPayload
                root.apply(compensation, context: context)
                throw error
            }
            cloudDeviceState = cloudState
            resetAffectsCloudProgress = cloudState.activeAccountID != nil
            installObservedSave(candidate, slices: slices)
            // Candidates captured by synchronous observers saw an incomplete
            // publication; advancing last also makes them obsolete after return.
            commitRevision &+= 1
        } catch {
            notePersistenceFailure(error, logging: "Failed to commit player save graph")
            throw PlayerSavePersistenceError.mapped(error)
        }
    }

    func savePrimaryGraph() throws {
        #if DEBUG
        if forcesNextDatabaseSaveFailure {
            forcesNextDatabaseSaveFailure = false
            throw PlayerSavePersistenceError.writeFailed
        }
        #endif
        try context.save()
    }

    /// A reset must reach the primary graph before replacing prior recoverable
    /// progress. Cleanup failure cannot undo that already durable reset.
    private func alignRecoveryAfterReset(_ save: PlayerSave) {
        if let pendingSaveRecovery, pendingSaveRecovery.hasPendingSave {
            do {
                try pendingSaveRecovery.clear()
            } catch {
                notePersistenceFailure(error, logging: "Failed to clear pending player save after reset")
                do {
                    try pendingSaveRecovery.write(
                        save: save, cloudState: root.cloudStatePayload,
                        outboxRecords: cloudOutbox?.storedRecords, labyrinthPayload: root.labyrinth?.mapPayload,
                    )
                } catch {
                    notePersistenceFailure(error, logging: "Failed to align pending player save after reset")
                }
            }
        }
        isPersistenceDegraded = usesMemoryFallback || pendingSaveRecovery?.hasPendingSave == true
        if pendingSaveRecovery?.hasPendingSave == true {
            scheduleRecoveryRetry()
        } else {
            lastPersistenceError = nil
        }
    }
}
