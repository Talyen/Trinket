import TrinketCore

public enum ItemSalvage {
    public static func isEligible(_ item: InventoryItem) -> Bool {
        !yields(for: item).isEmpty
    }

    public static func yields(for item: InventoryItem) -> [ResourceAmount] {
        guard !item.isTrinket,
              let (primary, secondary) = materials(for: item.baseType.slot) else { return [] }
        let quantity: Int
        switch item.rarity {
        case .basic: quantity = 8
        case .astral: quantity = 16
        case .unique: return []
        }
        return [
            ResourceAmount(primary, quantity),
            ResourceAmount(secondary, quantity / 2),
        ]
    }

    private static func materials(for slot: ItemSlot) -> (HomesteadResource, HomesteadResource)? {
        switch slot.baseItemSlot {
        case .weapon:
            (.iron, .wood)
        case .armor:
            (.hide, .stone)
        case .accessory:
            (.herbs, .gems)
        default:
            nil
        }
    }
}
