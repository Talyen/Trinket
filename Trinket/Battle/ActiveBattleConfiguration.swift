import SwiftUI

struct ActiveBattleConfiguration: Identifiable {
    let id = UUID()
    let hero: Combatant
    let pet: Combatant
    let heroProgression: CombatantProgression
    let petProgression: CombatantProgression
    let heroEquipmentLoadout: EquipmentLoadout
    let petEquipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState

    init(
        hero: Combatant,
        pet: Combatant,
        heroProgression: CombatantProgression = .initial,
        petProgression: CombatantProgression = .initial,
        heroEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        petEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        inventoryState: PlayerInventoryState = .initial
    ) {
        self.hero = hero
        self.pet = pet
        self.heroProgression = heroProgression
        self.petProgression = petProgression
        self.heroEquipmentLoadout = heroEquipmentLoadout
        self.petEquipmentLoadout = petEquipmentLoadout
        self.inventoryState = inventoryState
    }
}
