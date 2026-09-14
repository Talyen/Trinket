import Foundation
import SwiftData

extension PlayerSaveStore {
    func resetRoot(with save: PlayerSave) throws {
        let snapshot = currentSave
        let sanitized = PlayerSaveSanitizer.sanitize(save)
        try PlayerSaveSanitizer.validate(sanitized)
        try applyCandidate(sanitized, replacing: snapshot, slices: .all)
    }

    func resetRootDurably(with save: PlayerSave) throws {
        let snapshot = currentSave
        let sanitized = PlayerSaveSanitizer.sanitize(save)
        try PlayerSaveSanitizer.validate(sanitized)
        root.apply(sanitized, slices: .all, context: context)
        do {
            if !preservesUnreadableCloudState {
                root.cloudStatePayload = try JSONEncoder().encode(cloudDeviceState)
            }
            try savePrimaryGraph()
        } catch {
            compensate(snapshot: snapshot, slices: .all)
            lastPersistenceError = .writeFailed
            throw PlayerSavePersistenceError.writeFailed
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
                root.cloudStatePayload = try JSONEncoder().encode(previous)
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
        guard let recoveryConfiguration else { throw Self.memoryFallbackError }
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
            replacementRoot.cloudStatePayload = try JSONEncoder().encode(cloudDeviceState)
            replacementContext.insert(replacementRoot)
            container = replacement
            context = replacementContext
            root = replacementRoot
            usesMemoryFallback = false
            try saveGraph()
            clearPendingDeferredPersistence()
            installObservedSave(save)
        } catch {
            container = previous.container
            context = previous.context
            root = previous.root
            usesMemoryFallback = true
            isPersistenceDegraded = true
            lastPersistenceError = .writeFailed
            // PersistenceCheck: allow - prior recoverable progress is restored best-effort
            try? pendingSaveRecovery?.restorePendingData(pendingBackup)
            throw PlayerSavePersistenceError.writeFailed
        }
    }

    func savePrimaryGraph() throws {
        #if DEBUG
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

    func compensate(snapshot: PlayerSave, slices: PlayerSaveSlice) {
        restoreSnapshot(snapshot, slices: slices)
    }

    private func resetWithIncrementedSessionGeneration(_ base: PlayerSave) throws {
        var save = base
        save.sessionGeneration = currentSave.sessionGeneration &+ 1
        try resetRootDurably(with: save)
    }
}
