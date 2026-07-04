import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

struct ActiveBattleConfiguration: Identifiable {
    let id = UUID()
    let stageID: String?
    let hero: Combatant
    let pet: Combatant
    let enemy: Combatant?
    let enemyEncounterLevel: Int?
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
        enemyEncounterLevel: Int? = nil,
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
        self.enemyEncounterLevel = enemyEncounterLevel
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
        enemyEncounterLevel: Int? = nil,
        heroProgression: CombatantProgression = .initial,
        petProgression: CombatantProgression = .initial,
        heroEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        petEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        inventoryState: PlayerInventoryState = .initial,
        stageReward: StageReward? = nil,
        rewardItemNames: [String] = []
    ) -> ActiveBattleConfiguration {
        let scaledHero = CombatantLevelScaler.scale(combatant: hero, level: heroProgression.level)
        let scaledPet = CombatantLevelScaler.scale(combatant: pet, level: petProgression.level)
        let heroBuild = CombatBuildResolver.build(
            combatant: scaledHero,
            equipmentLoadout: heroEquipmentLoadout,
            inventory: inventoryState.items
        )
        let petBuild = CombatBuildResolver.build(
            combatant: scaledPet,
            equipmentLoadout: petEquipmentLoadout,
            inventory: inventoryState.items
        )
        return ActiveBattleConfiguration(
            stageID: stageID,
            hero: heroBuild.combatant,
            pet: petBuild.combatant,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
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
