import BattleEngine
import TrinketContent
import TrinketCore
import TrinketPersistence

struct PartyMemberBattleSnapshot: Equatable {
    let combatant: Combatant
    let progression: CombatantProgression
    let equipmentLoadout: EquipmentLoadout
    let modifiers: CombatModifierProfile
}

struct ActiveBattleConfiguration: Identifiable {
    let id = UUID()
    let stageID: String?
    let rngSeed: UInt64
    let hero: PartyMemberBattleSnapshot
    let pet: PartyMemberBattleSnapshot
    let enemy: Combatant?
    let enemyEncounterLevel: Int?
    let highestHeroLevel: Int
    let highestPetLevel: Int
    let enemyModifiers: CombatModifierProfile
    let inventoryState: PlayerInventoryState
    let stageReward: StageReward?
    let rewardItemNames: [String]

    func rosterContext(for combatantID: String) -> PartyMemberBattleSnapshot? {
        if combatantID == hero.combatant.id { return hero }
        if combatantID == pet.combatant.id { return pet }
        return nil
    }

    static func make(
        stageID: String? = nil,
        rngSeed: UInt64,
        hero: Combatant,
        pet: Combatant,
        roster: PlayerRosterStore,
        inventory: PlayerInventoryStore,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        stageReward: StageReward? = nil,
        rewardItemNames: [String] = []
    ) -> ActiveBattleConfiguration {
        let rosterState = roster.current
        let resolvedHeroProgression = rosterState.progression(for: hero)
        let resolvedPetProgression = rosterState.progression(for: pet)
        let resolvedHighestHeroLevel = rosterState.highestHeroLevel
        let resolvedHighestPetLevel = rosterState.highestPetLevel
        let resolvedHeroEquipmentLoadout = rosterState.equipmentLoadout(for: hero)
        let resolvedPetEquipmentLoadout = rosterState.equipmentLoadout(for: pet)
        let resolvedInventoryState = inventory.current

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
            hero: PartyMemberBattleSnapshot(
                combatant: heroBuild.combatant,
                progression: resolvedHeroProgression,
                equipmentLoadout: resolvedHeroEquipmentLoadout,
                modifiers: heroBuild.modifiers
            ),
            pet: PartyMemberBattleSnapshot(
                combatant: petBuild.combatant,
                progression: resolvedPetProgression,
                equipmentLoadout: resolvedPetEquipmentLoadout,
                modifiers: petBuild.modifiers
            ),
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: enemyEncounterLevel,
            highestHeroLevel: resolvedHighestHeroLevel,
            highestPetLevel: resolvedHighestPetLevel,
            enemyModifiers: enemyBuild.modifiers,
            inventoryState: resolvedInventoryState,
            stageReward: stageReward,
            rewardItemNames: rewardItemNames
        )
    }
}
