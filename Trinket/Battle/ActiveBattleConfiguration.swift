import SwiftUI

struct ActiveBattleConfiguration: Identifiable {
    let id = UUID()
    let stageID: String?
    let hero: Combatant
    let pet: Combatant
    let enemy: Combatant?
    let heroProgression: CombatantProgression
    let petProgression: CombatantProgression
    let heroEquipmentLoadout: EquipmentLoadout
    let petEquipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let stageReward: StageReward?
    let rewardItemNames: [String]

    init(
        stageID: String? = nil,
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        heroProgression: CombatantProgression = .initial,
        petProgression: CombatantProgression = .initial,
        heroEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        petEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        inventoryState: PlayerInventoryState = .initial,
        stageReward: StageReward? = nil,
        rewardItemNames: [String] = []
    ) {
        self.stageID = stageID
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
        self.heroProgression = heroProgression
        self.petProgression = petProgression
        self.heroEquipmentLoadout = heroEquipmentLoadout
        self.petEquipmentLoadout = petEquipmentLoadout
        self.inventoryState = inventoryState
        self.stageReward = stageReward
        self.rewardItemNames = rewardItemNames
    }
}
