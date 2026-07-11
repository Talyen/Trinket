import Foundation
import TrinketContent
import TrinketCore

public enum LabyrinthCompletion {
    public static let milestoneDepths: [Int] = [5, 10, 25, 50]

    public static func enemyLevel(for node: LabyrinthNode, effects: LabyrinthModifierEffects) -> Int {
        let base: Int = switch node.type {
        case .warden:
            max(1, node.depth + 3)
        case .elite, .gate:
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
        case .elite, .gate:
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

        // Item templates left empty; completion may roll a generated item for elites/wardens.
        return StageReward(gold: gold, itemTemplateIDs: [], materialRewards: materials)
    }

    public static func shouldRollItem(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> Bool {
        switch node.type.canonical {
        case .warden, .elite, .craft:
            true
        case .battle, .gate:
            Int.random(in: 0 ... 99, using: &randomNumberGenerator) < (8 + effects.itemDropBonusPercent)
        default:
            false
        }
    }

    /// Gold cost for the thin Crafting Altar forge action.
    public static func craftAltarCost(for node: LabyrinthNode) -> Int {
        max(8, 6 + node.depth * 2)
    }

    public static func complete(
        nodeID: String,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        save: inout PlayerSave
    ) {
        save.labyrinth.ensureMap()
        guard let node = save.labyrinth.node(id: nodeID), !node.isCleared else { return }

        let effects = save.labyrinth.effects(for: nodeID)
        let reward = rewards(for: node, effects: effects)
        let encounterLevel = enemyLevel(for: node, effects: effects)

        save.roster.grantGold(reward.gold + battleEarnedGold)
        // Battle XP is combat-only; rest/shop/mystery/craft grant gold/materials without XP.
        if node.type.isCombat {
            grantBattleExperience(enemyLevel: encounterLevel, effects: effects, to: hero, roster: &save.roster)
            grantBattleExperience(enemyLevel: encounterLevel, effects: effects, to: pet, roster: &save.roster)
        }

        let resolvedMaterials = materialRewards
            ?? save.homestead.adjustedMaterialRewards(reward.materialRewards)
        save.homestead.grant(resolvedMaterials)

        var itemRNG = SeededRandomNumberGenerator(
            seed: save.labyrinth.worldSeed &+ GameContent.stableSeed(for: "labyrinth-roll-\(nodeID)")
        )
        if shouldRollItem(for: node, effects: effects, using: &itemRNG) {
            grantGeneratedItem(nodeID: nodeID, effects: effects, save: &save)
        }

        if node.type.canonical == .craft {
            // Thin v1 craft altar: gold stipend already granted; bonus material.
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
        pet: Combatant,
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
        _ = pet
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
        let bases = GameContent.itemBaseTypes
        guard !bases.isEmpty else { return }
        var rng = SeededRandomNumberGenerator(
            seed: save.labyrinth.worldSeed &+ GameContent.stableSeed(for: "labyrinth-item-\(nodeID)")
        )
        let baseType = bases.randomElement(using: &rng) ?? bases[0]
        let astralRoll = Int.random(in: 0 ... 99, using: &rng)
        let rarity: Rarity = astralRoll < (15 + effects.astralChanceBonusPercent) ? .astral : .basic
        let item = ItemGenerator().generate(
            id: "labyrinth-\(nodeID)-\(save.inventory.items.count)",
            templateID: "\(baseType.id)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            keywordBias: effects.keywordBiases,
            using: &rng
        )
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
            : roster.highestPetLevel
        var award = StageCompletion.battleExperienceAward(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel
        )
        if effects.xpPercent != 0 {
            award = max(0, award + (award * effects.xpPercent) / 100)
        }
        roster.grantExperience(award, to: combatant)
    }
}

public enum LabyrinthUnlock {
    /// Chapter 1 complete OR any Aspect Floor 5 cleared.
    public static func isUnlocked(
        journey: JourneyProgressState,
        aspects: PlayerAspectsState,
        chapters: [Chapter] = GameContent.chapters
    ) -> Bool {
        if isChapterOneComplete(journey: journey, chapters: chapters) {
            return true
        }
        return aspects.highestClearedFloorByAspectID.values.contains { $0 >= 5 }
    }

    public static func unlockHint(
        journey: JourneyProgressState,
        aspects: PlayerAspectsState,
        chapters: [Chapter] = GameContent.chapters
    ) -> String {
        if isUnlocked(journey: journey, aspects: aspects, chapters: chapters) {
            return ""
        }
        return "Complete Chapter 1 or clear any Aspect Floor 5"
    }

    public static func isChapterOneComplete(
        journey: JourneyProgressState,
        chapters: [Chapter] = GameContent.chapters
    ) -> Bool {
        guard let chapter = chapters.first(where: { $0.id == "chapter-1" }) else {
            return false
        }
        return chapter.stages.allSatisfy { journey.completedStageIDs.contains($0.id) }
    }
}
