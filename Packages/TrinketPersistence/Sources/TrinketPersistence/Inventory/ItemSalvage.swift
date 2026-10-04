import TrinketContent
import TrinketCore

public enum ItemSalvageFailure: Error, Equatable, Sendable {
    case itemNotFound
    case ineligible
}

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

public enum ItemSalvageApplier {
    public static func salvage(itemID: String, save: inout PlayerSave) -> Result<[ResourceAmount], ItemSalvageFailure> {
        guard let item = save.inventory.items.first(where: { $0.id == itemID }) else {
            return .failure(.itemNotFound)
        }
        let yields = ItemSalvage.yields(for: item)
        guard !yields.isEmpty else { return .failure(.ineligible) }
        save.roster.unequip(itemID: itemID)
        save.inventory.removeItem(id: itemID)
        return .success(save.grantMaterials(yields))
    }
}

@MainActor
public extension PlayerSaveStore {
    @discardableResult
    func salvageItem(id: String) -> SaveTransactionResult<[ResourceAmount], ItemSalvageFailure> {
        persistTransaction(logging: "Failed to salvage item \(id)") { save in
            ItemSalvageApplier.salvage(itemID: id, save: &save)
        }
    }
}
