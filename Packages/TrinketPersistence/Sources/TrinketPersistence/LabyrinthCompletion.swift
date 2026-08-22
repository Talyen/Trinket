import Foundation
import TrinketContent
import TrinketCore

public enum LabyrinthCompletion {
    /// Ensures a Labyrinth map exists for the current save (eligible recruits applied).
    public static func enter(save: inout PlayerSave) {
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs
        )
    }

    /// Non-combat node gold stipend (rest/shop/mystery/recruit leave). Combat uses `BattleLoot`.
    public static func nonCombatGoldStipend(for node: LabyrinthNode) -> Int {
        switch node.type.canonical {
        case .shop, .mystery, .event, .craft, .recruit:
            2 + node.depth
        case .rest:
            1 + node.depth / 2
        case .battle, .boss, .entrance:
            0
        }
    }

    /// Stable inventory id for a node's Labyrinth find (forge or combat roll).
    public static func rewardItemID(forNodeID nodeID: String) -> String {
        "labyrinth-\(nodeID)"
    }

    public static func resolveCombatLoot(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage? {
        guard node.type.isCombat else { return nil }
        let encounterLevel = EncounterLevelResolver.labyrinthEnemyLevel(for: node)
        let enemyIsBoss = node.enemyID.flatMap(GameContent.enemy(matching:))?.isBoss == true
        return BattleLoot.resolveLabyrinth(
            node: node,
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            effects: effects,
            worldSeed: worldSeed,
            ownedTrinketIDs: ownedTrinketIDs,
            astralChanceBonusPercent: astralChanceBonusPercent
        )
    }

    // swiftlint:disable:next function_body_length
    public static func complete(
        nodeID: String,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootPackage? = nil,
        save: inout PlayerSave
    ) {
        let eligibleRecruitEventIDs = save.roster.eligibleRecruitEventIDs
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs
        )
        guard let node = save.labyrinth.node(id: nodeID), !node.isCleared else { return }

        let effects = save.labyrinth.effects(for: nodeID)
        let encounterLevel = EncounterLevelResolver.labyrinthEnemyLevel(for: node)

        if node.type.isCombat {
            let resolvedLoot = loot ?? resolveCombatLoot(
                for: node,
                effects: effects,
                worldSeed: save.worldSeed,
                ownedTrinketIDs: save.inventory.ownedTrinketIDs,
                astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent
            )
            let stageGold = resolvedLoot?.gold ?? 0
            save.applyGoldDelta(
                StageCompletion.resolvedGoldReward(
                    stageGold: stageGold,
                    battleEarnedGold: battleEarnedGold,
                    homestead: save.homestead
                )
            )
            StageCompletion.grantBattleExperience(
                enemyLevel: encounterLevel,
                to: hero,
                roster: &save.roster,
                xpPercent: effects.experienceEarnedPercent
            )
            StageCompletion.grantBattleExperience(
                enemyLevel: encounterLevel,
                to: companion,
                roster: &save.roster,
                xpPercent: effects.experienceEarnedPercent
            )

            let materials = materialRewards ?? resolvedLoot?.materials ?? []
            save.grantMaterials(materials)

            if let rewardItem {
                appendUniqueRewardItem(rewardItem, save: &save)
            } else if let resolvedLoot {
                appendUniqueRewardItem(resolvedLoot.item, save: &save)
            }
        } else {
            let stipend = nonCombatGoldStipend(for: node)
            save.applyGoldDelta(
                StageCompletion.resolvedGoldReward(
                    stageGold: stipend,
                    battleEarnedGold: battleEarnedGold,
                    homestead: save.homestead
                )
            )
            if let materialRewards {
                save.grantMaterials(materialRewards)
            }
            if let rewardItem {
                appendUniqueRewardItem(rewardItem, save: &save)
            }
        }

        save.labyrinth.markCleared(
            nodeID: nodeID,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs
        )
    }

    private static func appendUniqueRewardItem(_ item: InventoryItem, save: inout PlayerSave) {
        save.inventory.appendUniqueItem(item)
    }
}
