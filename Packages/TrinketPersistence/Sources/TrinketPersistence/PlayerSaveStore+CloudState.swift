import Foundation

@MainActor
extension PlayerSaveStore {
    func restoreCloudMetadataAndPendingSave(preservesPrevious: Bool) -> Bool {
        do {
            cloudOutbox = try CloudSaveOutbox(context: context)
        } catch {
            preservesUnreadableCloudState = true
            logger.error("iCloud outbox could not be read; keeping progress local: \(String(describing: error), privacy: .public)")
        }
        do {
            try pendingSaveRecovery?.restore(
                into: root, context: context, preservesPrevious: preservesPrevious,
                outbox: cloudOutbox,
            )
        } catch {
            // PersistenceCheck: allow - record is preserved aside when possible; retry persists newer progress
            archivePendingSaveIfCorrupt(error)
            logger.error(
                "Pending save could not be read; continuing with readable progress: \(String(describing: error), privacy: .public)",
            )
            isPersistenceDegraded = true
        }
        do {
            if let cloudOutbox {
                cloudDeviceState = try cloudOutbox.decode(root.cloudStatePayload)
                root.cloudStatePayload = try cloudOutbox.stage(cloudDeviceState)
            } else {
                cloudDeviceState = try CloudDeviceState.decode(root.cloudStatePayload)
            }
            resetAffectsCloudProgress = cloudDeviceState.activeAccountID != nil
        } catch {
            preservesUnreadableCloudState = true
            logger.error("iCloud metadata could not be read; keeping progress local: \(String(describing: error), privacy: .public)")
        }
        return !preservesUnreadableCloudState
    }

    /// Archives an unreadable pending record without destroying device-locked
    /// progress: a locked read stays for retry after first unlock.
    private func archivePendingSaveIfCorrupt(_ error: Error) {
        if let saveError = error as? PlayerSavePersistenceError, case .storeUnavailable = saveError {
            return
        }
        // PersistenceCheck: allow - corrupt record is preserved aside; retry persists newer progress
        try? pendingSaveRecovery?.moveCorruptAside()
    }

    func commitCloudState(
        _ state: CloudDeviceState,
        replacing save: PlayerSave? = nil,
        invalidatesSession: Bool = true,
    ) throws {
        let previous = cloudDeviceState
        cloudDeviceState = state
        do {
            if var save {
                let changed = invalidatesSession && CloudSaveSnapshot(currentSave) != CloudSaveSnapshot(save)
                save.sessionGeneration = changed ? currentSave.sessionGeneration &+ 1 : currentSave.sessionGeneration
                try resetRoot(with: save)
                if changed {
                    onExternalProgressChange?()
                }
            } else {
                try saveGraph()
            }
            resetAffectsCloudProgress = state.activeAccountID != nil
        } catch {
            // PersistenceCheck: allow - rollback is best-effort; original error is rethrown
            try? restoreCloudMetadata(previous)
            throw error
        }
    }

    func prepareLocalProduction() -> Bool {
        guard !isCloudSyncEnabled else { return true }
        guard let accountID = cloudDeviceState.activeAccountID else { return true }
        var state = cloudDeviceState
        state.archiving(
            CloudAccountArchive(snapshot: CloudSaveSnapshot(currentSave), state: state.account),
            for: accountID,
        )
        state.activeAccountID = nil
        state.account = CloudAccountState()
        do {
            try commitCloudState(state)
            return true
        } catch {
            return false
        }
    }
}
