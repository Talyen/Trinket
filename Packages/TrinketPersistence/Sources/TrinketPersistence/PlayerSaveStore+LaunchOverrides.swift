import TrinketContent

@MainActor
public extension PlayerSaveStore {
    func applyLaunchOverrides(skipStarterSelection: Bool, startingGold: Int?, equipmentPickerFixture: Bool) throws {
        #if DEBUG
        if equipmentPickerFixture {
            try performFixtureMutation { save in
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
            _ = persistAction(logging: "Failed to grant starting gold") { save -> Result<Void, Never> in
                save.roster.grantGold(startingGold)
                return .success(())
            }
        }
    }
}
