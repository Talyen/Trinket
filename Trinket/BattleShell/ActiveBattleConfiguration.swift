import BattleEngine
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

    func progression(for combatant: Combatant) -> CombatantProgression {
        if combatant.id == hero.id { return heroProgression }
        if combatant.id == pet.id { return petProgression }
        return .initial
    }

    func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        if combatant.id == hero.id { return heroEquipmentLoadout }
        if combatant.id == pet.id { return petEquipmentLoadout }
        return EquipmentLoadout()
    }

    static func make(
        stageID: String? = nil,
        rngSeed: UInt64,
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        roster: PlayerRosterStore? = nil,
        inventory: PlayerInventoryStore? = nil,
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
        let resolvedHeroProgression = roster?.current.progression(for: hero) ?? heroProgression
        let resolvedPetProgression = roster?.current.progression(for: pet) ?? petProgression
        let resolvedHighestHeroLevel = roster?.current.highestHeroLevel
            ?? highestHeroLevel
            ?? resolvedHeroProgression.level
        let resolvedHighestPetLevel = roster?.current.highestPetLevel
            ?? highestPetLevel
            ?? resolvedPetProgression.level
        let resolvedHeroEquipmentLoadout = roster?.current.equipmentLoadout(for: hero) ?? heroEquipmentLoadout
        let resolvedPetEquipmentLoadout = roster?.current.equipmentLoadout(for: pet) ?? petEquipmentLoadout
        let resolvedInventoryState = inventory?.current ?? inventoryState

        let scaledHero = CombatantLevelScaler.scale(combatant: hero, level: resolvedHeroProgression.level)
        let scaledPet = CombatantLevelScaler.scale(combatant: pet, level: resolvedPetProgression.level)
        let heroBuild = CombatBuildResolver.build(
            combatant: scaledHero,
            equipmentLoadout: resolvedHeroEquipmentLoadout,
            inventory: resolvedInventoryState.items
        )
        let petBuild = CombatBuildResolver.build(
            combatant: scaledPet,
            equipmentLoadout: resolvedPetEquipmentLoadout,
            inventory: resolvedInventoryState.items
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
            heroProgression: resolvedHeroProgression,
            petProgression: resolvedPetProgression,
            highestHeroLevel: resolvedHighestHeroLevel,
            highestPetLevel: resolvedHighestPetLevel,
            heroEquipmentLoadout: resolvedHeroEquipmentLoadout,
            petEquipmentLoadout: resolvedPetEquipmentLoadout,
            heroModifiers: heroBuild.modifiers,
            petModifiers: petBuild.modifiers,
            enemyModifiers: enemyBuild.modifiers,
            inventoryState: resolvedInventoryState,
            stageReward: stageReward,
            rewardItemNames: rewardItemNames
        )
    }

    private init(
        stageID: String?,
        rngSeed: UInt64,
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        heroProgression: CombatantProgression,
        petProgression: CombatantProgression,
        highestHeroLevel: Int,
        highestPetLevel: Int,
        heroEquipmentLoadout: EquipmentLoadout,
        petEquipmentLoadout: EquipmentLoadout,
        heroModifiers: CombatModifierProfile,
        petModifiers: CombatModifierProfile,
        enemyModifiers: CombatModifierProfile,
        inventoryState: PlayerInventoryState,
        stageReward: StageReward?,
        rewardItemNames: [String]
    ) {
        self.stageID = stageID
        self.rngSeed = rngSeed
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
        self.enemyEncounterLevel = enemyEncounterLevel
        self.heroProgression = heroProgression
        self.petProgression = petProgression
        self.highestHeroLevel = highestHeroLevel
        self.highestPetLevel = highestPetLevel
        self.heroEquipmentLoadout = heroEquipmentLoadout
        self.petEquipmentLoadout = petEquipmentLoadout
        self.heroModifiers = heroModifiers
        self.petModifiers = petModifiers
        self.enemyModifiers = enemyModifiers
        self.inventoryState = inventoryState
        self.stageReward = stageReward
        self.rewardItemNames = rewardItemNames
    }
}
