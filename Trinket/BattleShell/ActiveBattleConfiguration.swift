import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

struct ActiveBattleConfiguration: Identifiable {
    struct PartyMember: Equatable {
        let combatant: Combatant
        let progression: CombatantProgression
        let equipmentLoadout: EquipmentLoadout
        let modifiers: CombatModifierProfile
    }

    let id = UUID()
    let stageID: String?
    let rngSeed: UInt64
    let hero: PartyMember
    let pet: PartyMember
    let enemy: Combatant?
    let enemyEncounterLevel: Int?
    let highestHeroLevel: Int
    let highestPetLevel: Int
    let enemyModifiers: CombatModifierProfile
    let inventoryState: PlayerInventoryState
    let stageReward: StageReward?
    let rewardItemNames: [String]

    func partyMember(for combatantID: String) -> PartyMember? {
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
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        stageReward: StageReward? = nil,
        catalog: CombatCatalog = GameContentCombatCatalog()
    ) -> ActiveBattleConfiguration {
        let enemyBuild = resolvedEnemyBuild(enemy: enemy, catalog: catalog)
        return ActiveBattleConfiguration(
            stageID: stageID,
            rngSeed: rngSeed,
            hero: partyMember(
                combatant: hero,
                rosterState: rosterState,
                inventoryState: inventoryState,
                catalog: catalog
            ),
            pet: partyMember(
                combatant: pet,
                rosterState: rosterState,
                inventoryState: inventoryState,
                catalog: catalog
            ),
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: enemyEncounterLevel,
            highestHeroLevel: rosterState.highestHeroLevel,
            highestPetLevel: rosterState.highestPetLevel,
            enemyModifiers: enemyBuild.modifiers,
            inventoryState: inventoryState,
            stageReward: stageReward,
            rewardItemNames: rewardItemNames(for: stageReward)
        )
    }


    private static func partyMember(
        combatant: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        catalog: CombatCatalog
    ) -> PartyMember {
        let progression = rosterState.progression(for: combatant)
        let equipmentLoadout = rosterState.equipmentLoadout(for: combatant)
        let build = CombatBuildResolver.build(
            combatant: CombatantLevelScaler.scale(
                combatant: combatant,
                level: progression.level
            ),
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items,
            catalog: catalog
        )
        return PartyMember(
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
