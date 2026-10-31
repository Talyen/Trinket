import TrinketCore

public enum ItemSalvage {
    public static func isEligible(_ item: InventoryItem) -> Bool {
        recipe(for: item) != nil
    }

    public static func yields(for item: InventoryItem) -> [ResourceAmount] {
        guard let (primary, secondary, quantity) = recipe(for: item) else { return [] }
        return [
            ResourceAmount(primary, quantity),
            ResourceAmount(secondary, quantity / 2),
        ]
    }

    private static func recipe(for item: InventoryItem) -> (HomesteadResource, HomesteadResource, Int)? {
        let quantity: Int
        switch item.rarity {
        case .basic: quantity = 8
        case .astral: quantity = 16
        case .unique: return nil
        }
        guard let (primary, secondary) = materials(for: item.baseType.slot) else { return nil }
        return (primary, secondary, quantity)
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
