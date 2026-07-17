import Foundation
import TrinketContent
import TrinketCore

public enum LabyrinthCompletion {
    public static let milestoneDepths: [Int] = [5, 10, 25, 50]

    public static func enemyLevel(for node: LabyrinthNode, effects: LabyrinthModifierEffects) -> Int {
        let base: Int = switch node.type.canonical {
        case .boss:
            max(1, node.depth + 3)
        case .gate:
            max(1, node.depth + 1)
        default:
            max(1, node.depth)
        }
        // Soft power from threat modifiers: +1 level per 20% enemy power.
        let bonusLevels = effects.enemyPowerPercent / 20
        return base + bonusLevels
    }

    /// Non-combat node gold stipend (rest/shop/mystery/craft leave). Combat uses `BattleLoot`.
    public static func nonCombatGoldStipend(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects
    ) -> Int {
        let type = node.type.canonical
        let baseGold = switch type {
        case .shop, .mystery, .event, .craft:
            2 + node.depth
        case .rest:
            1 + node.depth / 2
        case .battle, .boss, .gate:
            0
        }
        return max(0, baseGold + (baseGold * effects.goldPercent) / 100)
    }

    /// Gold cost for the thin Crafting Altar forge action.
    public static func craftAltarCost(for node: LabyrinthNode) -> Int {
        max(8, 6 + node.depth * 2)
    }

    /// Applies Labyrinth modifier XP bonuses to a base battle award.
    public static func adjustedExperienceAward(_ base: Int, xpPercent: Int) -> Int {
        StageCompletion.adjustedExperienceAward(base, xpPercent: xpPercent)
    }

    /// Stable inventory id for a node's Labyrinth find (forge or combat roll).
    public static func rewardItemID(forNodeID nodeID: String) -> String {
        "labyrinth-\(nodeID)"
    }

    public static func resolveCombatLoot(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        worldSeed: UInt64
    ) -> BattleLootPackage? {
        guard node.type.isCombat else { return nil }
        let encounterLevel = enemyLevel(for: node, effects: effects)
        let enemyIsBoss = node.enemyID.flatMap(GameContent.enemy(matching:))?.isBoss == true
        return BattleLoot.resolveLabyrinth(
            node: node,
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            effects: effects,
            worldSeed: worldSeed
        )
    }

    /// Pre-rolls combat loot using the same seeds as `complete`, for victory chrome.
    public static func pendingCombatRewardItem(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        worldSeed: UInt64,
        astralChanceBonusPercent: Int = 0
    ) -> InventoryItem? {
        _ = astralChanceBonusPercent
        return resolveCombatLoot(for: node, effects: effects, worldSeed: worldSeed)?.item
    }

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
        save.labyrinth.ensureMap()
        guard let node = save.labyrinth.node(id: nodeID), !node.isCleared else { return }

        let effects = save.labyrinth.effects(for: nodeID)
        let encounterLevel = enemyLevel(for: node, effects: effects)

        if node.type.isCombat {
            let resolvedLoot = loot ?? resolveCombatLoot(
                for: node,
                effects: effects,
                worldSeed: save.labyrinth.worldSeed
            )
            let stageGold = resolvedLoot?.gold ?? 0
            save.roster.grantGold(
                save.homestead.effects.adjustedGold(stageGold + battleEarnedGold)
            )
            StageCompletion.grantBattleExperience(
                enemyLevel: encounterLevel,
                to: hero,
                roster: &save.roster,
                xpPercent: effects.xpPercent
            )
            StageCompletion.grantBattleExperience(
                enemyLevel: encounterLevel,
                to: companion,
                roster: &save.roster,
                xpPercent: effects.xpPercent
            )

            let materials = materialRewards ?? resolvedLoot?.materials ?? []
            save.homestead.grant(materials)

            if let rewardItem {
                appendUniqueRewardItem(rewardItem, save: &save)
            } else if let resolvedLoot {
                appendUniqueRewardItem(resolvedLoot.item, save: &save)
            }
        } else {
            let stipend = nonCombatGoldStipend(for: node, effects: effects)
            save.roster.grantGold(
                save.homestead.effects.adjustedGold(stipend + battleEarnedGold)
            )
            if let materialRewards {
                save.homestead.grant(materialRewards)
            }
            if node.type.canonical == .craft {
                // Leave without forging: gold stipend already granted; bonus material only.
                save.homestead.grant([ResourceAmount(.wood, 1)])
            }
            if let rewardItem {
                appendUniqueRewardItem(rewardItem, save: &save)
            }
        }

        save.labyrinth.markCleared(nodeID: nodeID)
        claimMilestonesIfNeeded(save: &save)
    }

    /// Spend gold at a Crafting Altar for a guaranteed generated item + clear the node.
    @discardableResult
    public static func forgeAtAltar(
        nodeID: String,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave
    ) -> Bool {
        save.labyrinth.ensureMap()
        guard let node = save.labyrinth.node(id: nodeID),
              node.type.canonical == .craft,
              !node.isCleared
        else { return false }

        let cost = craftAltarCost(for: node)
        guard save.roster.spendGold(cost) else { return false }

        let effects = save.labyrinth.effects(for: nodeID)
        grantGeneratedItem(nodeID: nodeID, effects: effects, save: &save)
        save.homestead.grant([ResourceAmount(.wood, 1)])
        // Craft is non-combat: complete()/forge never grant battle XP here.
        save.labyrinth.markCleared(nodeID: nodeID)
        claimMilestonesIfNeeded(save: &save)
        _ = hero
        _ = companion
        return true
    }

    public static func recordDefeat(nodeID: String, save: inout PlayerSave) {
        save.labyrinth.ensureMap()
        save.labyrinth.recordFail(nodeID: nodeID)
    }

    private static func claimMilestonesIfNeeded(save: inout PlayerSave) {
        let depth = save.labyrinth.deepestDepth
        for milestone in milestoneDepths where depth >= milestone {
            if save.labyrinth.claimedMilestoneDepths.insert(milestone).inserted {
                save.roster.grantGold(milestone * 2)
                save.homestead.grant([ResourceAmount(.wood, max(1, milestone / 5))])
            }
        }
    }

    private static func grantGeneratedItem(
        nodeID: String,
        effects: LabyrinthModifierEffects,
        save: inout PlayerSave
    ) {
        guard let item = makeGeneratedItem(
            nodeID: nodeID,
            effects: effects,
            worldSeed: save.labyrinth.worldSeed,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent
        ) else { return }
        appendUniqueRewardItem(item, save: &save)
    }

    private static func makeGeneratedItem(
        nodeID: String,
        effects: LabyrinthModifierEffects,
        worldSeed: UInt64,
        astralChanceBonusPercent: Int
    ) -> InventoryItem? {
        let bases = GameContent.itemBaseTypes
        guard !bases.isEmpty else { return nil }
        var rng = SeededRandomNumberGenerator(
            seed: worldSeed &+ GameContent.stableSeed(for: "labyrinth-item-\(nodeID)")
        )
        let baseType = bases.randomElement(using: &rng) ?? bases[0]
        let rarity = ItemRarityRoll.roll(
            baseAstralChancePercent: 15,
            astralChanceBonusPercent: effects.astralChanceBonusPercent + astralChanceBonusPercent,
            using: &rng
        )
        return ItemGenerator().generate(
            id: rewardItemID(forNodeID: nodeID),
            templateID: "\(baseType.id)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            keywordBias: effects.keywordBiases,
            using: &rng
        )
    }

    private static func appendUniqueRewardItem(_ item: InventoryItem, save: inout PlayerSave) {
        guard !save.inventory.items.contains(where: { $0.id == item.id }) else { return }
        save.inventory.items.append(item)
    }
}
