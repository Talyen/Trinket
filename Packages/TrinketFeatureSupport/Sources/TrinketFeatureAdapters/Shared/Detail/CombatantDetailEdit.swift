import TrinketContent
import TrinketCore
import TrinketPersistence

enum CombatantDetailEdit {
    case selectAbility(Ability)
    case equipItem(InventoryItem, ItemSlot)
    case unequipItem(ItemSlot)
    case resetTalents

    @MainActor
    func apply(to playerSave: PlayerSaveStore, for combatant: Combatant) -> Bool {
        guard playerSave.contentAccess.allowsCombatant(combatant.id),
              playerSave.roster.isUnlocked(combatant) else { return false }
        if case let .equipItem(item, slot) = self {
            guard playerSave.inventory.items.contains(where: { $0.id == item.id }),
                  playerSave.roster.equipmentLoadout(for: combatant).canEquip(item, in: slot, inventory: playerSave.inventory.items)
            else { return false }
        }
        return playerSave.mutateRoster { roster in
            switch self {
            case let .selectAbility(ability):
                roster.setLoadout(roster.loadout(for: combatant).selecting(ability), for: combatant)
            case let .equipItem(item, slot):
                var equipment = roster.equipmentLoadout(for: combatant)
                equipment.equip(item, in: slot, inventory: playerSave.inventory.items)
                roster.setEquipmentLoadout(equipment, for: combatant)
            case let .unequipItem(slot):
                var equipment = roster.equipmentLoadout(for: combatant)
                equipment.unequip(slot)
                roster.setEquipmentLoadout(equipment, for: combatant)
            case .resetTalents:
                roster.resetTalents(for: combatant.id)
            }
        }
    }
}
