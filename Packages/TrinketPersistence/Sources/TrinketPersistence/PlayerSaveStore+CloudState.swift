import Foundation

@MainActor
extension PlayerSaveStore {
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
