import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

struct ActiveBattleConfiguration: Identifiable {
    let id = UUID()
    let stageID: String?
    let rngSeed: UInt64
    let hero: Combatant
    let pet: Combatant
    let enemy: Combatant?
    let enemyEncounterLevel: Int?
    let heroProgression: CombatantProgression
    let petProgression: CombatantProgression
    let highestHeroLevel: Int
    let highestPetLevel: Int
    let heroEquipmentLoadout: EquipmentLoadout
    let petEquipmentLoadout: EquipmentLoadout
    let heroModifiers: CombatModifierProfile
    let petModifiers: CombatModifierProfile
    let enemyModifiers: CombatModifierProfile
    let inventoryState: PlayerInventoryState
    let stageReward: StageReward?
    let rewardItemNames: [String]

    init(
        stageID: String? = nil,
        rngSeed: UInt64 = UInt64.random(in: UInt64.min ... UInt64.max),
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        heroProgression: CombatantProgression = .initial,
        petProgression: CombatantProgression = .initial,
        highestHeroLevel: Int? = nil,
        highestPetLevel: Int? = nil,
        heroEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        petEquipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        heroModifiers: CombatModifierProfile = .zero,
        petModifiers: CombatModifierProfile = .zero,
        enemyModifiers: CombatModifierProfile = .zero,
        inventoryState: PlayerInventoryState = .initial,
        stageReward: StageReward? = nil,
        rewardItemNames: [String] = []
    ) {
        self.stageID = stageID
        self.rngSeed = rngSeed
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
        self.enemyEncounterLevel = enemyEncounterLevel
        self.heroProgression = heroProgression
        self.petProgression = petProgression
        self.highestHeroLevel = highestHeroLevel ?? heroProgression.level
        self.highestPetLevel = highestPetLevel ?? petProgression.level
        self.heroEquipmentLoadout = heroEquipmentLoadout
        self.petEquipmentLoadout = petEquipmentLoadout
        self.heroModifiers = heroModifiers
        self.petModifiers = petModifiers
        self.enemyModifiers = enemyModifiers
        self.inventoryState = inventoryState
        self.stageReward = stageReward
        self.rewardItemNames = rewardItemNames
    }

    static func make(
        stageID: String? = nil,
        rngSeed: UInt64 = UInt64.random(in: UInt64.min ... UInt64.max),
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        heroProgression: CombatantProgression = .initial,
        petProgression: CombatantProgression = .initial,
        highestHeroLevel: Int? = nil,
        highestPetLevel: Int? = nil,
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
        let enemyBuild: CombatBuild
        if let enemy,
           let catalogEnemy = GameContent.enemy(matching: enemy.id) {
            enemyBuild = CombatBuildResolver.build(enemy: catalogEnemy)
        } else {
            enemyBuild = CombatBuild(combatant: enemy ?? Enemy.fallbackCombatant, modifiers: .zero)
        }
        return ActiveBattleConfiguration(
            stageID: stageID,
            rngSeed: rngSeed,
            hero: heroBuild.combatant,
            pet: petBuild.combatant,
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: enemyEncounterLevel,
            heroProgression: heroProgression,
            petProgression: petProgression,
            highestHeroLevel: highestHeroLevel,
            highestPetLevel: highestPetLevel,
            heroEquipmentLoadout: heroEquipmentLoadout,
            petEquipmentLoadout: petEquipmentLoadout,
            heroModifiers: heroBuild.modifiers,
            petModifiers: petBuild.modifiers,
            enemyModifiers: enemyBuild.modifiers,
            inventoryState: inventoryState,
            stageReward: stageReward,
            rewardItemNames: rewardItemNames
        )
    }
}
