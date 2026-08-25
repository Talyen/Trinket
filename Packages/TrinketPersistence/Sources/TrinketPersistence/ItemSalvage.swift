import Foundation
import TrinketContent
import TrinketCore

public enum ItemSalvageResult: Equatable, Sendable {
    case success(yields: [ResourceAmount])
    case itemNotFound
    case ineligible
}

/// Deterministic material yields for salvaging inventory gear.
public enum ItemSalvage {
    /// Single eligibility source for UI affordances and the salvage applier:
    /// Trinkets and Uniques can never be salvaged.
    public static func isEligible(_ item: InventoryItem) -> Bool {
        item.baseType.slot != .trinket && item.rarity != .unique
    }

    public static func yields(for item: InventoryItem) -> [ResourceAmount] {
        let (primary, secondary) = materials(for: item.baseType.slot)
        let (primaryQuantity, secondaryQuantity) = quantities(for: item.rarity)
        return [
            ResourceAmount(primary, primaryQuantity),
            ResourceAmount(secondary, secondaryQuantity),
        ]
    }

    private static func materials(for slot: ItemSlot) -> (HomesteadResource, HomesteadResource) {
        switch slot.baseItemSlot {
        case .weapon:
            (.iron, .wood)
        case .armor:
            (.hide, .stone)
        case .accessory:
            (.herbs, .crystal)
        case .trinket:
            preconditionFailure("Trinkets cannot be salvaged.")
        default:
            preconditionFailure("Unsupported salvage slot: \(slot)")
        }
    }

    private static func quantities(for rarity: Rarity) -> (Int, Int) {
        switch rarity {
        case .basic:
            (8, 4)
        case .astral:
            (16, 8)
        case .unique:
            preconditionFailure("Uniques cannot be salvaged.")
        }
    }
}

/// Removes an inventory item, unequips it from all loadouts, and grants salvage materials.
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
