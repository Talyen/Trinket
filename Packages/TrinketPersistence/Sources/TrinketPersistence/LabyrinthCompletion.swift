import Foundation
import TrinketContent
import TrinketCore

public enum LabyrinthCompletion {
    public static func enter(save: inout PlayerSave) {
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs,
        )
    }

    public static func nonCombatGoldStipend(for node: LabyrinthNode) -> Int {
        switch node.type.canonical {
        case .shop, .mystery, .event, .craft, .recruit, .rest:
            2 + node.depth
        case .battle, .boss, .entrance:
            0
        }
    }

    public static func rewardItemID(forNodeID nodeID: String) -> String {
        "labyrinth-\(nodeID)"
    }

    public static func resolveCombatLoot(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        encounterLevel: Int? = nil,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String>,
        astralChanceBonusPercent: Int = 0,
    ) -> BattleLootPackage? {
        guard node.type.isCombat else { return nil }
        let level = encounterLevel ?? EncounterLevelResolver.labyrinthEnemyLevel(for: node)
        let enemyIsBoss = VictoryRewardApplier.isBoss(enemyID: node.enemyID)
        return BattleLoot.resolveLabyrinth(
            node: node,
            encounterLevel: level,
            enemyIsBoss: enemyIsBoss,
            effects: effects,
            worldSeed: worldSeed,
            ownedTrinketIDs: ownedTrinketIDs,
            ownedUniqueIDs: ownedUniqueIDs,
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    public static func complete(
        nodeID: String,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootPackage? = nil,
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave,
    ) {
        let eligibleRecruitEventIDs = save.roster.eligibleRecruitEventIDs
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
        )
        guard let node = save.labyrinth.node(id: nodeID), !node.isCleared else { return }

        let effects = save.labyrinth.effects(for: nodeID)
        let encounterLevel = enemyEncounterLevel
            ?? EncounterLevelResolver.partyAdjusted(
                EncounterLevelResolver.labyrinthEnemyLevel(for: node),
                partyAverageLevel: save.roster.activePartyAverageLevel,
            )

        if node.type.isCombat {
            let resolvedLoot = loot ?? resolveCombatLoot(
                for: node,
                effects: effects,
                encounterLevel: encounterLevel,
                worldSeed: save.worldSeed,
                ownedTrinketIDs: save.inventory.ownedTrinketIDs,
                ownedUniqueIDs: save.inventory.ownedUniqueIDs,
                astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
            )
            StageCompletion.grantVictoryRewards(
                hero: hero,
                companion: companion,
                encounterLevel: encounterLevel,
                stageGold: resolvedLoot?.gold ?? 0,
                battleEarnedGold: battleEarnedGold,
                xpPercent: effects.experienceEarnedPercent,
                materials: materialRewards ?? resolvedLoot?.materials ?? [],
                item: rewardItem ?? resolvedLoot?.item,
                save: &save,
            )
        } else {
            StageCompletion.grantVictoryRewards(
                hero: hero,
                companion: companion,
                encounterLevel: encounterLevel,
                stageGold: nonCombatGoldStipend(for: node),
                battleEarnedGold: battleEarnedGold,
                grantsCombatExperience: false,
                materials: materialRewards ?? loot?.materials ?? [],
                item: rewardItem ?? loot?.item,
                save: &save,
            )
        }

        save.labyrinth.markCleared(
            nodeID: nodeID,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
        )
    }
}
