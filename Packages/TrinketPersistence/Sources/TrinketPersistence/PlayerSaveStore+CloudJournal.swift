import Foundation

@MainActor
extension PlayerSaveStore {
    func recordCloudMutation(from snapshot: PlayerSave, to candidate: PlayerSave, slices: PlayerSaveSlice) throws {
        guard isCloudSyncEnabled, cloudDeviceState.activeAccountID != nil,
              !cloudDeviceState.account.resetRequested,
              cloudDeviceState.account.journal != nil
              || cloudDeviceState.account.base?.revision.snapshot == CloudSaveSnapshot(snapshot)
        else { return }
        var state = cloudDeviceState
        let mutation = CloudSaveMutation(
            id: UUID().uuidString, changedSliceMask: slices.rawValue,
            before: CloudSaveSnapshot(snapshot), after: CloudSaveSnapshot(candidate),
        )
        state.account.journal = CloudSaveJournalCompaction.compact(
            (state.account.journal ?? []) + [mutation],
            pending: state.account.pending?.mutations ?? [],
        )
        try setCloudDeviceState(state)
    }
}

private enum CloudSaveJournalCompaction {
    static func compact(_ journal: [CloudSaveMutation], pending: [CloudSaveMutation]) -> [CloudSaveMutation] {
        let protectedIDs = Set(pending.map(\.id))
        let start = (journal.lastIndex { protectedIDs.contains($0.id) }).map { $0 + 1 } ?? 0
        guard journal.count - start > 64 else { return journal }
        let end = journal.count - 16
        let older = journal[start ..< end]
        guard let first = older.first, let last = older.last else { return journal }
        let combined = CloudSaveMutation(
            id: UUID().uuidString,
            changedSliceMask: older.reduce(0) { $0 | $1.changedSliceMask },
            before: first.before, after: last.after,
        )
        return Array(journal[..<start]) + [combined] + Array(journal[end...])
    }
}
