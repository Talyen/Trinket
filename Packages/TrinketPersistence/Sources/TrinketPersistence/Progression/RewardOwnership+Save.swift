import TrinketContent

public extension RewardOwnership {
    init(_ inventory: PlayerInventoryState) {
        self.init(ownedTrinketIDs: inventory.ownedTrinketIDs, ownedUniqueIDs: inventory.ownedUniqueIDs)
    }

    init(_ save: PlayerSave) {
        self.init(save.inventory)
    }
}
