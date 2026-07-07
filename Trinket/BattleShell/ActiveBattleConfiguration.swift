import BattleEngine
import Foundation
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

    static func resolvedEncounter(
        for stage: Stage,
        contentCatalog: PlayerContentCatalog = GameContentPlayerCatalog()
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID = stage.encounter.battleEnemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID),
              let chapter = contentCatalog.chapters.first(where: { $0.id == stage.chapterID })
        else { return nil }

        let level = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        return (
            CombatantLevelScaler.scale(enemy: catalogEnemy, level: level),
            level
        )
    }

    @MainActor
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
        catalog: CombatCatalog = GameContentCombatCatalog()
    ) -> ActiveBattleConfiguration {
        let rosterState = roster.current
        let resolvedHighestHeroLevel = rosterState.highestHeroLevel
        let resolvedHighestPetLevel = rosterState.highestPetLevel
        let resolvedInventoryState = inventory.current

        let heroSnapshot = partyMemberSnapshot(
            combatant: hero,
            rosterState: rosterState,
            inventoryState: resolvedInventoryState,
            catalog: catalog
        )
        let petSnapshot = partyMemberSnapshot(
            combatant: pet,
            rosterState: rosterState,
            inventoryState: resolvedInventoryState,
            catalog: catalog
        )
        let enemyBuild = resolvedEnemyBuild(enemy: enemy, catalog: catalog)
        return ActiveBattleConfiguration(
            stageID: stageID,
            rngSeed: rngSeed,
            hero: heroSnapshot,
            pet: petSnapshot,
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: enemyEncounterLevel,
            highestHeroLevel: resolvedHighestHeroLevel,
            highestPetLevel: resolvedHighestPetLevel,
            enemyModifiers: enemyBuild.modifiers,
            inventoryState: resolvedInventoryState,
            stageReward: stageReward,
            rewardItemNames: rewardItemNames(for: stageReward)
        )
    }

    private static func partyMemberSnapshot(
        combatant: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        catalog: CombatCatalog
    ) -> PartyMemberBattleSnapshot {
        let progression = rosterState.progression(for: combatant)
        let equipmentLoadout = rosterState.equipmentLoadout(for: combatant)
        let scaledCombatant = CombatantLevelScaler.scale(
            combatant: combatant,
            level: progression.level
        )
        let build = CombatBuildResolver.build(
            combatant: scaledCombatant,
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items,
            catalog: catalog
        )
        return PartyMemberBattleSnapshot(
            combatant: build.combatant,
            progression: progression,
            equipmentLoadout: equipmentLoadout,
            modifiers: build.modifiers
        )
    }

    private static func resolvedEnemyBuild(
        enemy: Combatant?,
        catalog: CombatCatalog
    ) -> CombatBuild {
        if let enemy,
           let catalogEnemy = catalog.enemy(matching: enemy.id) {
            return CombatBuildResolver.build(enemy: catalogEnemy, catalog: catalog)
        }
        return CombatBuild(combatant: enemy ?? Enemy.fallbackCombatant, modifiers: .zero)
    }

    private static func rewardItemNames(for stageReward: StageReward?) -> [String] {
        guard let stageReward else { return [] }
        return stageReward.itemTemplateIDs.compactMap { templateID in
            GameContent.itemTemplate(matching: templateID)?.displayName
        }
    }
}
