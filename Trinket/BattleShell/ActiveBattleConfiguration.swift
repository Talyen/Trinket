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

    struct AspectBattle: Equatable, Hashable {
        let aspectID: AspectID
        let floor: Int
    }

    struct LabyrinthBattle: Equatable, Hashable {
        let nodeID: String
    }

    let id = UUID()
    let stageID: String?
    let aspectBattle: AspectBattle?
    let labyrinthBattle: LabyrinthBattle?
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
    let pendingRewardItem: InventoryItem?

    var hasProgressionRewards: Bool {
        stageID != nil || aspectBattle != nil || labyrinthBattle != nil
    }

    var resumeToken: ActiveBattleResumeToken? {
        if let stageID {
            return .journey(stageID: stageID)
        }
        if let aspectBattle {
            return .aspect(aspectID: aspectBattle.aspectID, floor: aspectBattle.floor)
        }
        if let labyrinthBattle {
            return .labyrinth(nodeID: labyrinthBattle.nodeID)
        }
        return nil
    }

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

    static func resolvedAspectEncounter(
        for floor: AspectFloor
    ) -> (combatant: Combatant, level: Int)? {
        guard let catalogEnemy = GameContent.enemy(matching: floor.enemyID) else { return nil }
        let level = AspectCompletion.enemyLevel(for: floor)
        return (
            CombatantLevelScaler.scale(enemy: catalogEnemy, level: level),
            level
        )
    }

    static func resolvedLabyrinthEncounter(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID = node.enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        let level = LabyrinthCompletion.enemyLevel(for: node, effects: effects)
        return (
            CombatantLevelScaler.scale(enemy: catalogEnemy, level: level),
            level
        )
    }

    @MainActor
    static func make(
        stageID: String? = nil,
        aspectBattle: AspectBattle? = nil,
        labyrinthBattle: LabyrinthBattle? = nil,
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
        var rng = SeededRandomNumberGenerator(seed: rngSeed)
        let pendingRewardItem = pendingAspectRewardItem(aspectBattle: aspectBattle, using: &rng)
        let templateNames = rewardItemNames(for: stageReward)
        let rewardNames = templateNames.isEmpty
            ? pendingRewardItem.map { [$0.displayName] } ?? []
            : templateNames
        return ActiveBattleConfiguration(
            stageID: stageID,
            aspectBattle: aspectBattle,
            labyrinthBattle: labyrinthBattle,
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
            rewardItemNames: rewardNames,
            pendingRewardItem: pendingRewardItem
        )
    }

    private static func pendingAspectRewardItem<RNG: RandomNumberGenerator>(
        aspectBattle: AspectBattle?,
        using randomNumberGenerator: inout RNG
    ) -> InventoryItem? {
        guard let aspectBattle,
              let floor = GameContent.aspectFloor(
                  aspectID: aspectBattle.aspectID,
                  floor: aspectBattle.floor
              )
        else { return nil }
        return AspectCompletion.makeAspectFloorItem(for: floor, using: &randomNumberGenerator)
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
