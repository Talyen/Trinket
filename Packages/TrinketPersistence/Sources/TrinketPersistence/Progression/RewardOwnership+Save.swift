import TrinketContent

public extension RewardOwnership {
    init(_ inventory: PlayerInventoryState) {
        var trinkets: Set<String> = []
        var uniques: Set<String> = []
        for item in inventory.items {
            if item.isTrinket {
                trinkets.insert(item.templateID)
            }
            if item.rarity == .unique {
                uniques.insert(item.templateID)
            }
        }
        self.init(ownedTrinketIDs: trinkets, ownedUniqueIDs: uniques)
    }

    init(_ save: PlayerSave) {
        self.init(save.inventory)
    }
}
