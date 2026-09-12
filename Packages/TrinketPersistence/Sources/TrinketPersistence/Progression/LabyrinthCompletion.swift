import Foundation
import TrinketContent
import TrinketCore

public enum LabyrinthCompletion {
    public static func enter(save: inout PlayerSave, access: ContentAccessPolicy = .fullGame) {
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs(access: access),
        )
    }

    public static func nonCombatGoldStipend(for node: LabyrinthNode) -> Int {
        switch node.type {
        case .shop, .mystery, .recruit:
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
    ) -> BattleLootResult? {
        guard node.type.isCombat else { return nil }
        let level = encounterLevel ?? EncounterLevelResolver.labyrinthEnemyLevel(for: node)
        let enemyIsBoss = VictoryRewardApplier.isBoss(enemyID: node.enemyID)
        return VictoryRewardApplier.resolveLoot(
            .labyrinth(node: node, effects: effects),
            encounterLevel: level,
            enemyIsBoss: enemyIsBoss,
            worldSeed: worldSeed,
            ownership: RewardOwnership(
                ownedTrinketIDs: ownedTrinketIDs,
                ownedUniqueIDs: ownedUniqueIDs,
            ),
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    public static func complete(
        nodeID: String,
        hero: Combatant,
        companion: Combatant,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave,
        access: ContentAccessPolicy = .fullGame,
    ) {
        let eligibleRecruitEventIDs = save.roster.eligibleRecruitEventIDs(access: access)
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
        )
        guard let node = save.labyrinth.node(id: nodeID), !node.isCleared else { return }

        let effects = save.labyrinth.effects(for: nodeID)
        let encounterLevel = enemyEncounterLevel
            ?? EncounterLevelResolver.labyrinthAdjusted(
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
            VictoryRewardApplier.grantVictoryRewards(
                hero: hero,
                companion: companion,
                encounterLevel: encounterLevel,
                stageGold: resolvedLoot?.gold ?? 0,
                battleGold: battleGold,
                award: award,
                experienceEarnedPercent: effects.experienceEarnedPercent,
                materialRewards: VictoryRewardApplier.grantedMaterials(
                    override: materialRewards,
                    loot: resolvedLoot,
                ),
                item: VictoryRewardApplier.grantedItem(override: rewardItem, loot: resolvedLoot),
                save: &save,
            )
        } else {
            VictoryRewardApplier.grantVictoryRewards(
                hero: hero,
                companion: companion,
                encounterLevel: encounterLevel,
                stageGold: nonCombatGoldStipend(for: node),
                battleGold: battleGold,
                award: award,
                grantsCombatExperience: false,
                materialRewards: VictoryRewardApplier.grantedMaterials(override: materialRewards, loot: loot),
                item: VictoryRewardApplier.grantedItem(override: rewardItem, loot: loot),
                save: &save,
            )
        }

        save.labyrinth.markCleared(
            nodeID: nodeID,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
        )
    }
}
