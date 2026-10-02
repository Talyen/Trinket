import TrinketContent
import TrinketCore

public enum ItemSalvageFailure: Error, Equatable, Sendable {
    case itemNotFound
    case ineligible
}

public enum ItemSalvage {
    public static func isEligible(_ item: InventoryItem) -> Bool {
        !item.isTrinket && item.rarity != .unique && !yields(for: item).isEmpty
    }

    public static func yields(for item: InventoryItem) -> [ResourceAmount] {
        guard let (primary, secondary) = materials(for: item.baseType.slot),
              let (primaryQuantity, secondaryQuantity) = quantities(for: item.rarity)
        else {
            return []
        }
        return [
            ResourceAmount(primary, primaryQuantity),
            ResourceAmount(secondary, secondaryQuantity),
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

    private static func quantities(for rarity: Rarity) -> (Int, Int)? {
        switch rarity {
        case .basic:
            (8, 4)
        case .astral:
            (16, 8)
        case .unique:
            nil
        }
    }
}

public enum ItemSalvageApplier {
    public static func salvage(itemID: String, save: inout PlayerSave) -> Result<[ResourceAmount], ItemSalvageFailure> {
        guard let item = save.inventory.items.first(where: { $0.id == itemID }) else {
            return .failure(.itemNotFound)
        }
        guard ItemSalvage.isEligible(item) else { return .failure(.ineligible) }

        let yields = ItemSalvage.yields(for: item)
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
