struct ItemBaseType: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let slot: ItemSlot
}

struct ItemAffix: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let description: String
}

extension ItemAffix {
    static let placeholder = ItemAffix(
        id: "placeholder",
        title: "Placeholder",
        description: "No effect yet."
    )
}

struct InventoryItem: Identifiable, Equatable, Hashable {
    let id: String
    let baseType: ItemBaseType
    let rarity: Rarity
    let displayName: String
    let affixes: [ItemAffix]
}

struct EquipmentLoadout: Equatable, Hashable {
    var itemIDsBySlot: [ItemSlot: String]

    init(itemIDsBySlot: [ItemSlot: String] = [:]) {
        self.itemIDsBySlot = itemIDsBySlot
    }

    func itemID(for slot: ItemSlot) -> String? {
        itemIDsBySlot[slot]
    }

    mutating func equip(_ item: InventoryItem, in slot: ItemSlot? = nil) {
        itemIDsBySlot[slot ?? item.baseType.slot] = item.id
    }

    mutating func unequip(_ slot: ItemSlot) {
        itemIDsBySlot[slot] = nil
    }
}
