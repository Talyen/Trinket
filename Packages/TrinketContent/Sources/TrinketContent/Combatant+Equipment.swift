import Foundation
import TrinketCore

public extension Combatant.Role {
    var equipmentSlots: [ItemSlot] {
        switch self {
        case .hero:
            [.weapon, .armor, .trinket]
        case .companion:
            [.trinket, .armor, .secondaryTrinket]
        case .enemy:
            []
        }
    }
}

public extension EquipmentLoadout {
    func sanitized(for combatant: Combatant, inventory: [InventoryItem]) -> EquipmentLoadout {
        let itemsByID = Dictionary(uniqueKeysWithValues: inventory.map { ($0.id, $0) })
        var sanitized = EquipmentLoadout()

        for slot in combatant.role.equipmentSlots {
            guard
                let itemID = itemID(for: slot),
                let item = itemsByID[itemID],
                slot.accepts(item.baseType.slot)
            else {
                continue
            }
            sanitized.equip(item, in: slot)
        }

        return sanitized
    }
}
