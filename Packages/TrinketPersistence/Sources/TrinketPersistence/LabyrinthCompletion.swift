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

    /// Non-combat node gold stipend (shop/mystery/recruit leave). Combat uses `BattleLoot`.
    public static func nonCombatGoldStipend(for node: LabyrinthNode) -> Int {
        switch node.type.canonical {
        case .shop, .mystery, .event, .craft, .recruit:
            2 + node.depth
        case .battle, .boss, .rest, .entrance:
            0
        }
    }

    /// Fraction of max Health restored by one Campfire rest.
    private static let campfireRestFraction = 0.3

    /// Campfire rest: restores 30% of max Health (floored), capped at max.
    public static func campfireRestHealth(current: Int, maxHealth: Int) -> Int {
        let gain = Int((Double(maxHealth) * campfireRestFraction).rounded(.down))
        return min(maxHealth, current + gain)
    }

    /// Stable inventory id for a node's Labyrinth find (forge or combat roll).
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
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage? {
        guard node.type.isCombat else { return nil }
        let level = encounterLevel ?? EncounterLevelResolver.labyrinthEnemyLevel(for: node)
        let enemyIsBoss = node.enemyID.flatMap(GameContent.enemy(matching:))?.isBoss == true
        return BattleLoot.resolveLabyrinth(
            node: node,
            encounterLevel: level,
            enemyIsBoss: enemyIsBoss,
            effects: effects,
            worldSeed: worldSeed,
            ownedTrinketIDs: ownedTrinketIDs,
            ownedUniqueIDs: ownedUniqueIDs,
            astralChanceBonusPercent: astralChanceBonusPercent
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
        partyRunHealth: [String: Int]? = nil,
        save: inout PlayerSave
    ) {
        let eligibleRecruitEventIDs = save.roster.eligibleRecruitEventIDs
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs
        )
        guard let node = save.labyrinth.node(id: nodeID), !node.isCleared else { return }

        let effects = save.labyrinth.effects(for: nodeID)
        let encounterLevel = enemyEncounterLevel
            ?? EncounterLevelResolver.labyrinthEnemyLevel(for: node)

        if node.type.isCombat {
            let resolvedLoot = loot ?? resolveCombatLoot(
                for: node,
                effects: effects,
                encounterLevel: encounterLevel,
                worldSeed: save.worldSeed,
                ownedTrinketIDs: save.inventory.ownedTrinketIDs,
                ownedUniqueIDs: save.inventory.ownedUniqueIDs,
                astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent
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
                save: &save
            )
        } else {
            StageCompletion.grantVictoryRewards(
                hero: hero,
                companion: companion,
                encounterLevel: encounterLevel,
                stageGold: nonCombatGoldStipend(for: node),
                battleEarnedGold: battleEarnedGold,
                grantsCombatExperience: false,
                materials: materialRewards ?? [],
                item: rewardItem,
                save: &save
            )
        }

        if let partyRunHealth {
            save.labyrinth.runHealthByCombatantID = partyRunHealth
        }

        save.labyrinth.markCleared(
            nodeID: nodeID,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs
        )
    }
}
