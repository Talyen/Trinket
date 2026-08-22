import Foundation
import TrinketCore

public extension Combatant.Role {
    var equipmentSlots: [ItemSlot] {
        switch self {
        case .hero:
            [.weapon, .armor, .secondaryWeapon, .accessory, .secondaryAccessory, .trinket]
        case .companion:
            [.trinket, .accessory, .secondaryTrinket]
        case .enemy:
            []
        }
    }
}

public extension EquipmentLoadout {
    func sanitized(for combatant: Combatant, inventory: [InventoryItem]) -> EquipmentLoadout {
        let itemsByID = Dictionary(uniqueKeysWithValues: inventory.map { ($0.id, $0) })
        var sanitized = EquipmentLoadout()
        var claimedItemIDs = Set<String>()

        for slot in combatant.role.equipmentSlots {
            guard
                let itemID = itemID(for: slot),
                !claimedItemIDs.contains(itemID),
                let item = itemsByID[itemID],
                slot.accepts(item.baseType.slot)
            else {
                continue
            }
            claimedItemIDs.insert(itemID)
            sanitized.equip(item, in: slot, inventory: inventory)
        }

        return sanitized
    }
}
