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
        case .weapon, .secondaryWeapon:
            (.iron, .wood)
        case .armor:
            (.hide, .stone)
        case .accessory, .secondaryAccessory:
            (.herbs, .crystal)
        case .trinket, .secondaryTrinket:
            preconditionFailure("Trinkets cannot be salvaged.")
        }
    }

    private static func quantities(for rarity: Rarity) -> (Int, Int) {
        switch rarity {
        case .basic:
            (8, 4)
        case .astral:
            (16, 8)
        }
    }
}

/// Removes an inventory item, unequips it from all loadouts, and grants salvage materials.
public enum ItemSalvageApplier {
    public static func salvage(itemID: String, save: inout PlayerSave) -> ItemSalvageResult {
        guard let item = save.inventory.items.first(where: { $0.id == itemID }) else {
            return .itemNotFound
        }
        guard item.baseType.slot != .trinket else { return .ineligible }

        let yields = ItemSalvage.yields(for: item)
        unequip(itemID: itemID, from: &save.roster)
        save.inventory.removeItem(id: itemID)
        return .success(yields: save.grantMaterials(yields))
    }

    private static func unequip(itemID: String, from roster: inout PlayerRosterState) {
        for (combatantID, var loadout) in roster.equipmentLoadouts {
            var didChange = false
            for slot in ItemSlot.allCases where loadout.itemID(for: slot) == itemID {
                loadout.unequip(slot)
                didChange = true
            }
            if didChange {
                roster.equipmentLoadouts[combatantID] = loadout
            }
        }
    }
}
