import Foundation
import TrinketContent
import TrinketCore

public enum ItemSalvageResult: Equatable, Sendable {
    case success(yields: [ResourceAmount])
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
            (.herbs, .crystal)
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
    public static func salvage(itemID: String, save: inout PlayerSave) -> ItemSalvageResult {
        guard let item = save.inventory.items.first(where: { $0.id == itemID }) else {
            return .itemNotFound
        }
        guard ItemSalvage.isEligible(item) else { return .ineligible }

        let yields = ItemSalvage.yields(for: item)
        save.roster.unequip(itemID: itemID)
        save.inventory.removeItem(id: itemID)
        return .success(yields: save.grantMaterials(yields))
    }
}

@MainActor
public extension PlayerSaveStore {
    @discardableResult
    func salvageItem(id: String) -> ItemSalvageResult? {
        var result: ItemSalvageResult = .itemNotFound
        guard persistBatch(logging: "Failed to salvage item \(id)", { save in
            result = ItemSalvageApplier.salvage(itemID: id, save: &save)
        }) else {
            return nil
        }
        return result
    }

    func corruptItem(
        id: String,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemCorruptionResult? {
        var result: ItemCorruptionResult = .itemNotFound
        guard persistBatch(logging: "Failed to corrupt item \(id)", { save in
            result = ItemCorruptionApplier.corrupt(itemID: id, save: &save, using: &randomNumberGenerator)
        }) else {
            return nil
        }
        return result
    }
}
