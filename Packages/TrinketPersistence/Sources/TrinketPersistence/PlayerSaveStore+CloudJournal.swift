import Foundation

@MainActor
extension PlayerSaveStore {
    func cloudStateRecordingMutation(
        from snapshot: PlayerSave, to candidate: PlayerSave, slices: PlayerSaveSlice,
        receipts suppliedReceipts: [SaveEconomicReceipt]? = nil,
        actions: [ResolvedSaveAction]? = nil,
    ) throws -> CloudDeviceState {
        guard isCloudSyncEnabled, cloudDeviceState.activeAccountID != nil,
              !cloudDeviceState.account.resetRequested,
              cloudDeviceState.account.journal != nil
              || cloudDeviceState.account.base?.revision.snapshot == CloudSaveSnapshot(snapshot)
        else { return cloudDeviceState }
        var state = cloudDeviceState
        var positions = state.account.collectionPositions ?? [:]
        for (resource, position) in state.account.base?.productionClaims?.positions ?? [:] {
            positions[resource] = max(positions[resource, default: 0], position)
        }
        let actionRecords = try actions.map { actions in
            try ResolvedSaveAction.records(actions, following: CloudSaveSnapshot(snapshot), positions: &positions)
        }
        let receipts = try (actions == nil ? suppliedReceipts : nil).map { receipts in
            try receipts.map { receipt in
                let positioned = try receipt.positioningCollections(&positions)
                try positioned.validate()
                return positioned
            }
        }
        if actionRecords != nil {
            state.formatVersion = 4
        } else if receipts != nil {
            state.formatVersion = max(3, state.formatVersion)
        }
        state.account.collectionPositions = positions.isEmpty ? nil : positions
        let mutation = CloudSaveMutation(
            id: UUID().uuidString, changedSliceMask: slices.rawValue,
            before: CloudSaveSnapshot(snapshot), after: CloudSaveSnapshot(candidate),
            economy: receipts == nil && actions == nil ? CloudEconomicAction.record(from: snapshot, to: candidate) : nil,
            receipts: receipts, actions: actionRecords,
            collectionPositions: receipts == nil && actions == nil ? nil : positions,
        )
        // A snapshot pair cannot preserve the separate payouts in a batch.
        // Retain each durable action, including IDs already in a pending request.
        var journal = state.account.journal ?? CloudSaveJournal()
        journal.append(mutation)
        state.account.journal = journal
        return state
    }
}
