import Foundation
import SwiftData

@MainActor
extension PlayerSaveStore {
    enum ResetOrdering {
        /// Cloud-install: preserves the incoming candidate in the pending
        /// recovery file before the primary write.
        case preserveCandidateFirst
        /// Local reset: writes the primary graph first and only replaces the
        /// pending record when the fresh reset is durable.
        case preservePriorOnFailure
    }

    /// Cloud-install path: preserves the incoming candidate in the pending
    /// recovery file before the primary write (via `applyCandidate`).
    func resetRoot(with save: PlayerSave) throws {
        try resetRoot(with: save, ordering: .preserveCandidateFirst)
    }

    func resetRoot(with save: PlayerSave, ordering: ResetOrdering) throws {
        let snapshot = currentSave
        let sanitized = try PlayerSaveSanitizer.sanitizeAndValidate(save)
        switch ordering {
        case .preserveCandidateFirst:
            try applyCandidate(sanitized, replacing: snapshot, slices: .all, recordsCloudMutation: false)
        case .preservePriorOnFailure:
            try resetRootDurably(with: sanitized, alreadySanitized: true, snapshot: snapshot)
        }
    }

    /// Local-reset path: writes the primary graph first and only replaces the
    /// pending record when the fresh reset is durable, so a failed reset
    /// retains prior recoverable progress.
    func resetRootDurably(with save: PlayerSave) throws {
        try resetRootDurably(with: save, alreadySanitized: false, snapshot: currentSave)
    }

    private func resetRootDurably(with save: PlayerSave, alreadySanitized: Bool, snapshot: PlayerSave) throws {
        let sanitized = alreadySanitized ? save : try PlayerSaveSanitizer.sanitizeAndValidate(save)
        root.apply(sanitized, slices: .all, context: context)
        do {
            try encodeCloudStateForSave()
            try savePrimaryGraph()
        } catch {
            restoreSnapshot(snapshot, slices: .all)
            let mapped = PlayerSavePersistenceError.mapped(error)
            lastPersistenceError = mapped
            throw mapped
        }
        if let pendingSaveRecovery, pendingSaveRecovery.hasPendingSave {
            do {
                try pendingSaveRecovery.clear()
            } catch {
                // PersistenceCheck: allow - primary reset is durable; pending is aligned best-effort
                try? pendingSaveRecovery.write(
                    save: sanitized,
                    cloudState: root.cloudStatePayload,
                )
            }
        }
        isPersistenceDegraded = usesMemoryFallback
            || (pendingSaveRecovery?.hasPendingSave == true)
        lastPersistenceError = nil
        clearPendingDeferredPersistence()
        installObservedSave(sanitized, slices: .all)
    }

    public func resetGameplayProgress() throws {
        let previous = cloudDeviceState
        if cloudDeviceState.activeAccountID != nil {
            cloudDeviceState.account.pending = nil
            cloudDeviceState.account.resetRequested = true
            cloudDeviceState.account.journal = nil
        }
        do {
            if usesMemoryFallback {
                try resetDurableStorage()
            } else {
                try resetWithIncrementedSessionGeneration(.fresh)
            }
        } catch {
            cloudDeviceState = previous
            if !preservesUnreadableCloudState {
                // PersistenceCheck: allow - rollback is best-effort; original error is rethrown
                try? setCloudDeviceState(previous)
            }
            throw error
        }
    }

    public func applyTestSeed() throws {
        try resetWithIncrementedSessionGeneration(.testSeed)
    }

    public func unlockAllContent() throws {
        try resetWithIncrementedSessionGeneration(.unlockedAll)
    }

    func resetDurableStorage() throws {
        guard let recoveryConfiguration else {
            throw PlayerSavePersistenceError.storeUnavailable(
                "Couldn't reset saved progress on this device.",
            )
        }
        let previous = (container: container, context: context, root: root)
        // PersistenceCheck: allow - backup is best-effort; missing backup clears a partial reset record
        let pendingBackup = try? pendingSaveRecovery?.pendingData()
        do {
            try PlayerSaveStoreConfiguration.cleanStoreFiles(
                at: recoveryConfiguration.url,
                includingRecovery: false,
            )
            let replacement = try ModelContainer(for: PlayerSaveGraph.schema, configurations: recoveryConfiguration)
            let replacementContext = ModelContext(replacement)
            replacementContext.autosaveEnabled = false
            try replacementContext.delete(model: PlayerSaveRoot.self)
            var save = PlayerSaveSanitizer.sanitize(.fresh)
            save.sessionGeneration = currentSave.sessionGeneration &+ 1
            let replacementRoot = PlayerSaveRoot(save: save)
            replacementContext.insert(replacementRoot)
            container = replacement
            context = replacementContext
            root = replacementRoot
            usesMemoryFallback = false
            // Recompute cloud enablement now that durable storage is back;
            // init disables cloud on memory fallback, so re-enable when a
            // cloud transport was requested.
            if cloudSyncRequested {
                enableCloudAfterDurableRecovery(
                    transport: CloudKitSaveTransport(containerIdentifier: Self.cloudKitContainerIdentifier),
                )
            }
            try setCloudDeviceState(cloudDeviceState)
            try saveGraph()
            clearPendingDeferredPersistence()
            installObservedSave(save)
        } catch {
            container = previous.container
            context = previous.context
            root = previous.root
            usesMemoryFallback = true
            isPersistenceDegraded = true
            let mapped = PlayerSavePersistenceError.mapped(error)
            lastPersistenceError = mapped
            // PersistenceCheck: allow - prior recoverable progress is restored best-effort
            try? pendingSaveRecovery?.restorePendingData(pendingBackup)
            throw mapped
        }
    }

    func savePrimaryGraph() throws {
        #if DEBUG
        // Mirrors the total-failure check in saveGraph for paths that bypass
        // it (durable resets). Normal commits throw before the pending write;
        // resets throw here, after root.apply but before any file mutation,
        // so prior recoverable progress is preserved.
        if forcesNextSaveFailure {
            forcesNextSaveFailure = false
            throw NSError(domain: "PlayerSaveStoreTests", code: 1)
        }
        if forcesNextDatabaseSaveFailure {
            forcesNextDatabaseSaveFailure = false
            throw PlayerSavePersistenceError.writeFailed
        }
        #endif
        try context.save()
    }

    private func resetWithIncrementedSessionGeneration(_ base: PlayerSave) throws {
        var save = base
        save.sessionGeneration = currentSave.sessionGeneration &+ 1
        try resetRootDurably(with: save)
    }
}
