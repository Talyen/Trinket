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
    let heroModifiers: CombatModifierProfile
    let petModifiers: CombatModifierProfile
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
        heroModifiers: CombatModifierProfile = .zero,
        petModifiers: CombatModifierProfile = .zero,
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
        self.heroModifiers = heroModifiers
        self.petModifiers = petModifiers
        self.inventoryState = inventoryState
        self.stageReward = stageReward
        self.rewardItemNames = rewardItemNames
    }

    static func make(
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
    ) -> ActiveBattleConfiguration {
        let heroBuild = CombatBuildResolver.build(
            combatant: hero,
            equipmentLoadout: heroEquipmentLoadout,
            inventory: inventoryState
        )
        let petBuild = CombatBuildResolver.build(
            combatant: pet,
            equipmentLoadout: petEquipmentLoadout,
            inventory: inventoryState
        )
        return ActiveBattleConfiguration(
            stageID: stageID,
            hero: heroBuild.combatant,
            pet: petBuild.combatant,
            enemy: enemy,
            heroProgression: heroProgression,
            petProgression: petProgression,
            heroEquipmentLoadout: heroEquipmentLoadout,
            petEquipmentLoadout: petEquipmentLoadout,
            heroModifiers: heroBuild.modifiers,
            petModifiers: petBuild.modifiers,
            inventoryState: inventoryState,
            stageReward: stageReward,
            rewardItemNames: rewardItemNames
        )
    }
}
