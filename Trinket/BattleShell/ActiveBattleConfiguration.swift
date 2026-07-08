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
        for stage: Stage
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID = stage.encounter.battleEnemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID),
              let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
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
        stageReward: StageReward? = nil
    ) -> ActiveBattleConfiguration {
        let enemyBuild = resolvedEnemyBuild(enemy: enemy)
        return ActiveBattleConfiguration(
            stageID: stageID,
            rngSeed: rngSeed,
            hero: partyMember(
                combatant: hero,
                rosterState: rosterState,
                inventoryState: inventoryState
            ),
            pet: partyMember(
                combatant: pet,
                rosterState: rosterState,
                inventoryState: inventoryState
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
        inventoryState: PlayerInventoryState
    ) -> PartyMember {
        let progression = rosterState.progression(for: combatant)
        let equipmentLoadout = rosterState.equipmentLoadout(for: combatant)
        let build = CombatBuildResolver.build(
            combatant: CombatantLevelScaler.scale(
                combatant: combatant,
                level: progression.level
            ),
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items
        )
        return PartyMember(
            combatant: build.combatant,
            progression: progression,
            equipmentLoadout: equipmentLoadout,
            modifiers: build.modifiers
        )
    }

    private static func resolvedEnemyBuild(
        enemy: Combatant?
    ) -> CombatBuild {
        guard let enemy else {
            return CombatBuild(combatant: Enemy.fallbackCombatant, modifiers: .zero)
        }
        // Preserve the encounter combatant (already journey-scaled by `resolvedEncounter`).
        // Only resolve trait modifiers from the catalog entry — do not replace scaled stats
        // with the catalog base combatant.
        if let catalogEnemy = GameContent.enemy(matching: enemy.id) {
            let catalogBuild = CombatBuildResolver.build(enemy: catalogEnemy)
            return CombatBuild(combatant: enemy, modifiers: catalogBuild.modifiers)
        }
        return CombatBuild(combatant: enemy, modifiers: .zero)
    }

    private static func rewardItemNames(for stageReward: StageReward?) -> [String] {
        guard let stageReward else { return [] }
        return stageReward.itemTemplateIDs.compactMap { templateID in
            GameContent.itemTemplate(matching: templateID)?.displayName
        }
    }
}
