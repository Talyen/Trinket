import Foundation

@MainActor
extension PlayerSaveStore {
    func recordCloudMutation(
        from snapshot: PlayerSave, to candidate: PlayerSave, slices: PlayerSaveSlice,
        receipts suppliedReceipts: [SaveEconomicReceipt]? = nil,
    ) throws {
        guard isCloudSyncEnabled, cloudDeviceState.activeAccountID != nil,
              !cloudDeviceState.account.resetRequested,
              cloudDeviceState.account.journal != nil
              || cloudDeviceState.account.base?.revision.snapshot == CloudSaveSnapshot(snapshot)
        else { return }
        var state = cloudDeviceState
        var positions = state.account.collectionPositions ?? [:]
        for (resource, position) in state.account.base?.productionClaims?.positions ?? [:] {
            positions[resource] = max(positions[resource, default: 0], position)
        }
        let receipts = try suppliedReceipts.map { receipts in
            try receipts.map { receipt in
                let positioned = try receipt.positioningCollections(&positions)
                try positioned.validate()
                return positioned
            }
        }
        if receipts != nil {
            state.formatVersion = 3
        }
        state.account.collectionPositions = positions.isEmpty ? nil : positions
        let mutation = CloudSaveMutation(
            id: UUID().uuidString, changedSliceMask: slices.rawValue,
            before: CloudSaveSnapshot(snapshot), after: CloudSaveSnapshot(candidate),
            economy: receipts == nil ? CloudEconomicAction.record(from: snapshot, to: candidate) : nil,
            receipts: receipts,
            collectionPositions: receipts == nil ? nil : positions,
        )
        // A snapshot pair cannot preserve the separate payouts in a batch.
        // Retain each durable action, including IDs already in a pending request.
        var journal = state.account.journal ?? CloudSaveJournal()
        journal.append(mutation)
        state.account.journal = journal
        cloudDeviceState = state
    }
}
