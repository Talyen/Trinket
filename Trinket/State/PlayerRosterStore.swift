import SwiftUI

@Observable
final class PlayerRosterStore {
    var current: PlayerRosterState = .initial

    var heroes: [Combatant] {
        current.configuredCombatants(GameContent.heroes)
    }

    var pets: [Combatant] {
        current.configuredCombatants(GameContent.pets)
    }

    func progression(for combatant: Combatant) -> CombatantProgression {
        current.progression(for: combatant)
    }

    func loadout(for combatant: Combatant) -> AbilityLoadout {
        current.loadout(for: combatant)
    }

    func setLoadout(_ loadout: AbilityLoadout, for combatant: Combatant) {
        current.setLoadout(loadout, for: combatant)
    }

    func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        current.equipmentLoadout(for: combatant)
    }

    func setEquipmentLoadout(_ loadout: EquipmentLoadout, for combatant: Combatant) {
        current.setEquipmentLoadout(loadout, for: combatant)
    }

    func equippedItem(for slot: ItemSlot, combatant: Combatant, inventory: PlayerInventoryState) -> InventoryItem? {
        current.equippedItem(for: slot, combatant: combatant, inventory: inventory)
    }

    func configuredCombatants(_ combatants: [Combatant]) -> [Combatant] {
        current.configuredCombatants(combatants)
    }

    func configuredCombatant(_ combatant: Combatant) -> Combatant {
        current.configuredCombatant(combatant)
    }
}
