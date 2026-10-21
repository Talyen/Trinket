import Foundation

@MainActor
extension PlayerSaveStore {
    func restoreCloudMetadataAndPendingSave(preservesPrevious: Bool) throws -> Bool {
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
            logger.error(
                "Pending save could not be restored; preserving progress for retry: \(String(describing: error), privacy: .public)",
            )
            // The sidecar may contain progress absent from the primary graph.
            // No writable store may escape until restoration has succeeded.
            throw PlayerSavePersistenceError.storeUnavailable("Saved progress must be restored before opening this store.")
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

    func commitCloudState(
        _ state: CloudDeviceState,
        replacing save: PlayerSave? = nil,
        invalidatesSession: Bool = true,
    ) throws {
        let snapshot = currentSave
        var candidate = snapshot
        var changed = false
        if let save {
            changed = invalidatesSession && snapshot.hasDomainDifference(from: save)
            candidate = try PlayerSaveSanitizer.sanitizeAndValidate(save)
            candidate.sessionGeneration = changed ? snapshot.sessionGeneration &+ 1 : snapshot.sessionGeneration
        }
        try commitGraph(candidate, replacing: snapshot, slices: save == nil ? [] : .all, cloudState: state)
        if changed {
            onExternalProgressChange?()
        }
    }

    func prepareLocalProduction() throws {
        guard !isCloudSyncEnabled else { return }
        guard let accountID = cloudDeviceState.activeAccountID else { return }
        var state = cloudDeviceState
        state.archiving(
            CloudAccountArchive(snapshot: CloudSaveSnapshot(currentSave), state: state.account),
            for: accountID,
        )
        state.activeAccountID = nil
        state.account = CloudAccountState()
        try commitCloudState(state)
    }
}
