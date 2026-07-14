import Foundation
import TrinketContent
import TrinketCore

public enum LabyrinthCompletion {
    public static let milestoneDepths: [Int] = [5, 10, 25, 50]

    public static func enemyLevel(for node: LabyrinthNode, effects: LabyrinthModifierEffects) -> Int {
        let base: Int = switch node.type {
        case .warden:
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

    public static func rewards(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects
    ) -> StageReward {
        let type = node.type.canonical
        let baseGold = switch type {
        case .warden:
            10 + node.depth * 3
        case .gate:
            6 + node.depth * 2
        case .battle:
            4 + node.depth * 2
        case .shop, .mystery, .event, .craft:
            2 + node.depth
        case .rest:
            1 + node.depth / 2
        }
        let gold = max(0, baseGold + (baseGold * effects.goldPercent) / 100)

        var materials: [ResourceAmount] = []
        if type == .warden || node.depth % 3 == 0 {
            materials = [ResourceAmount(.wood, type == .warden ? 3 : 1)]
        }

        // Item templates left empty; completion may roll a generated item for wardens.
        return StageReward(gold: gold, itemTemplateIDs: [], materialRewards: materials)
    }

    public static func shouldRollItem(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> Bool {
        switch node.type.canonical {
        case .warden:
            true
        case .battle, .gate:
            Int.random(in: 0 ... 99, using: &randomNumberGenerator) < (8 + effects.itemDropBonusPercent)
        case .craft:
            // Craft items come only from forgeAtAltar (paid). Leaving without forging
            // must not mint a free generated item.
            false
        default:
            false
        }
    }

    /// Gold cost for the thin Crafting Altar forge action.
    public static func craftAltarCost(for node: LabyrinthNode) -> Int {
        max(8, 6 + node.depth * 2)
    }

    /// Applies Labyrinth modifier XP bonuses to a base battle award.
    public static func adjustedExperienceAward(_ base: Int, xpPercent: Int) -> Int {
        guard base > 0, xpPercent != 0 else { return max(0, base) }
        return max(0, base + (base * xpPercent) / 100)
    }

    /// Stable inventory id for a node's Labyrinth find (forge or combat roll).
    public static func rewardItemID(forNodeID nodeID: String) -> String {
        "labyrinth-\(nodeID)"
    }

    /// Pre-rolls a combat drop using the same seeds as `complete`, for victory chrome.
    public static func pendingCombatRewardItem(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        worldSeed: UInt64,
        astralChanceBonusPercent: Int = 0
    ) -> InventoryItem? {
        var rollRNG = SeededRandomNumberGenerator(
            seed: worldSeed &+ GameContent.stableSeed(for: "labyrinth-roll-\(node.id)")
        )
        guard shouldRollItem(for: node, effects: effects, using: &rollRNG) else { return nil }
        return makeGeneratedItem(
            nodeID: node.id,
            effects: effects,
            worldSeed: worldSeed,
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
        save: inout PlayerSave
    ) {
        save.labyrinth.ensureMap()
        guard let node = save.labyrinth.node(id: nodeID), !node.isCleared else { return }

        let effects = save.labyrinth.effects(for: nodeID)
        let reward = rewards(for: node, effects: effects)
        let encounterLevel = enemyLevel(for: node, effects: effects)

        save.roster.grantGold(save.homestead.effects.adjustedGold(reward.gold + battleEarnedGold))
        // Battle XP is combat-only; rest/shop/mystery/craft grant gold/materials without XP.
        if node.type.isCombat {
            grantBattleExperience(enemyLevel: encounterLevel, effects: effects, to: hero, roster: &save.roster)
            grantBattleExperience(enemyLevel: encounterLevel, effects: effects, to: companion, roster: &save.roster)
        }

        let resolvedMaterials = StageCompletion.resolvedMaterialRewards(
            stageReward: reward,
            override: materialRewards
        )
        save.homestead.grant(resolvedMaterials)

        if let rewardItem {
            appendUniqueRewardItem(rewardItem, save: &save)
        } else {
            var itemRNG = SeededRandomNumberGenerator(
                seed: save.labyrinth.worldSeed &+ GameContent.stableSeed(for: "labyrinth-roll-\(nodeID)")
            )
            if shouldRollItem(for: node, effects: effects, using: &itemRNG) {
                grantGeneratedItem(nodeID: nodeID, effects: effects, save: &save)
            }
        }

        if node.type.canonical == .craft {
            // Leave without forging: gold stipend already granted; bonus material only.
            save.homestead.grant([ResourceAmount(.wood, 1)])
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

    private static func grantBattleExperience(
        enemyLevel: Int,
        effects: LabyrinthModifierEffects,
        to combatant: Combatant,
        roster: inout PlayerRosterState
    ) {
        let playerLevel = roster.progression(for: combatant).level
        let highestLevel = combatant.role == .hero
            ? roster.highestHeroLevel
            : roster.highestCompanionLevel
        let award = adjustedExperienceAward(
            StageCompletion.battleExperienceAward(
                playerLevel: playerLevel,
                enemyLevel: enemyLevel,
                highestLevel: highestLevel
            ),
            xpPercent: effects.xpPercent
        )
        roster.grantExperience(award, to: combatant)
    }
}
