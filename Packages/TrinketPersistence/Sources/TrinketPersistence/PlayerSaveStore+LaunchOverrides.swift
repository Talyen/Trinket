import TrinketContent

@MainActor
public extension PlayerSaveStore {
    func applyLaunchOverrides(skipStarterSelection: Bool, startingGold: Int?, equipmentPickerFixture: Bool) throws {
        #if DEBUG
        if equipmentPickerFixture {
            try performBatchMutation { save in
                let equipped = save.roster.equipmentLoadouts.values.flatMap(\.itemIDsBySlot.values)
                let retained = Set(equipped).union(["longsword-astral"])
                save.inventory.items.removeAll { !retained.contains($0.id) }
            }
        }
        #endif
        if skipStarterSelection, starterSelection.phase != .complete {
            try performBatchMutation { $0.starterSelection = .complete }
        }
        if let startingGold, startingGold > 0 {
            persistBatch(logging: "Failed to grant starting gold") { save, recordReceipt in
                let before = save
                save.roster.grantGold(startingGold)
                recordReceipt(.reward(from: before, to: save))
            }
        }
    }
}
