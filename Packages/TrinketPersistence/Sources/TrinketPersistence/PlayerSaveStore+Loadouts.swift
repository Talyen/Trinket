import TrinketContent
import TrinketCore

public enum CombatantLoadoutEdit {
    case selectAbility(Ability)
    case equipItem(InventoryItem, ItemSlot)
    case unequipItem(ItemSlot)
    case resetTalents
}

@MainActor
public extension PlayerSaveStore {
    func editCombatant(_ edit: CombatantLoadoutEdit, for combatant: Combatant) -> Bool {
        guard contentAccess.allowsCombatant(combatant.id),
              roster.isUnlocked(combatant) else { return false }
        if case let .equipItem(item, slot) = edit {
            guard inventory.items.contains(where: { $0.id == item.id }),
                  roster.equipmentLoadout(for: combatant).canEquip(item, in: slot, inventory: inventory.items)
            else { return false }
        }
        return mutateRoster { roster in
            switch edit {
            case let .selectAbility(ability):
                roster.setLoadout(roster.loadout(for: combatant).selecting(ability), for: combatant)
            case let .equipItem(item, slot):
                var equipment = roster.equipmentLoadout(for: combatant)
                equipment.equip(item, in: slot, inventory: inventory.items)
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

    @discardableResult
    func selectParty(hero: Combatant? = nil, companion: Combatant? = nil) -> Bool {
        guard hero != nil || companion != nil else { return false }
        if let hero {
            guard contentAccess.allowsCombatant(hero.id), roster.heroes.contains(where: { $0.id == hero.id }) else { return false }
        }
        if let companion {
            guard contentAccess.allowsCombatant(companion.id),
                  roster.companions.contains(where: { $0.id == companion.id }) else { return false }
        }
        return mutateRoster(logging: "Failed to persist party selection") { roster in
            if let hero {
                roster.setActiveHero(hero)
            }
            if let companion {
                roster.setActiveCompanion(companion)
            }
        }
    }
}
