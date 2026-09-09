import Foundation
import TrinketContent
import TrinketCore

public struct LootRequest: Equatable, Sendable {
    public var seedSalt: String
    public var itemID: String
    public var keywordBias: Set<Keyword>
    public var goldFoundPercent: Int
    public var materialsFoundPercent: Int

    public init(
        seedSalt: String,
        itemID: String,
        keywordBias: Set<Keyword> = [],
        goldFoundPercent: Int = 0,
        materialsFoundPercent: Int = 0,
    ) {
        self.seedSalt = seedSalt
        self.itemID = itemID
        self.keywordBias = keywordBias
        self.goldFoundPercent = goldFoundPercent
        self.materialsFoundPercent = materialsFoundPercent
    }
}

public struct RewardOwnership: Equatable, Sendable {
    public var ownedTrinketIDs: Set<String>
    public var ownedUniqueIDs: Set<String>

    public init(ownedTrinketIDs: Set<String> = [], ownedUniqueIDs: Set<String> = []) {
        self.ownedTrinketIDs = ownedTrinketIDs
        self.ownedUniqueIDs = ownedUniqueIDs
    }

    public init(_ inventory: PlayerInventoryState) {
        ownedTrinketIDs = inventory.ownedTrinketIDs
        ownedUniqueIDs = inventory.ownedUniqueIDs
    }

    public init(_ save: PlayerSave) {
        self.init(save.inventory)
    }
}

public extension LootRequest {
    static func journey(stage: Stage) -> LootRequest {
        LootRequest(seedSalt: "battle-loot-journey-\(stage.id)", itemID: "\(stage.id)-loot")
    }

    static func spire(floor: SpireFloor) -> LootRequest {
        var keywordBias: Set<Keyword> = []
        if let spire = GameContent.spire(id: floor.spireID) {
            keywordBias.insert(spire.keyword)
        }
        return LootRequest(
            seedSalt: "battle-loot-spire-\(floor.spireID.rawValue)-\(floor.floor)",
            itemID: "spire-\(floor.spireID.rawValue)-floor-\(floor.floor)-loot",
            keywordBias: keywordBias,
        )
    }

    static func labyrinth(node: LabyrinthNode, effects: LabyrinthModifierEffects) -> LootRequest {
        LootRequest(
            seedSalt: "battle-loot-labyrinth-\(node.id)",
            itemID: LabyrinthCompletion.rewardItemID(forNodeID: node.id),
            goldFoundPercent: effects.goldFoundPercent,
            materialsFoundPercent: effects.materialsFoundPercent,
        )
    }
}

public enum VictoryRewardApplier {
    public static func isBoss(enemyID: String?) -> Bool {
        guard let enemyID else { return false }
        return GameContent.enemy(matching: enemyID)?.isBoss == true
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleGold: BattleGoldFlow,
        goldFoundPercent: Int,
    ) -> Int {
        BattleRewardPlan(
            stageGold: stageGold, goldFindPercent: goldFoundPercent,
            heroExperience: 0, companionExperience: 0, materials: [], items: [],
        ).resolve(battleGold: battleGold).goldDelta
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleGold: BattleGoldFlow,
        homestead: PlayerHomesteadState,
    ) -> Int {
        resolvedGoldReward(
            stageGold: stageGold,
            battleGold: battleGold,
            goldFoundPercent: homestead.effects.goldFindPercent,
        )
    }

    public static func battleExperienceAward(
        playerLevel: Int,
        enemyLevel: Int,
        highestLevel: Int,
        experienceEarnedPercent: Int = 0,
    ) -> Int {
        let raw = CombatRounding.scaled(
            ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: playerLevel,
                enemyLevel: enemyLevel,
                highestLevel: highestLevel,
            ),
            byPercent: experienceEarnedPercent,
        )
        return ExperienceScaling.cappedAward(
            raw,
            requiredXP: CombatantProgression.requiredXP(forLevel: playerLevel),
        )
    }

    public static func resolveLoot(
        _ request: LootRequest,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        worldSeed: UInt64,
        ownership: RewardOwnership,
        astralChanceBonusPercent: Int = 0,
    ) -> BattleLootResult {
        var rng = SeededRandomNumberGenerator(
            seed: GameContent.encounterSeed(worldSeed, salt: request.seedSalt),
        )
        return BattleLoot.resolve(
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            itemID: request.itemID,
            keywordBias: request.keywordBias,
            ownedTrinketIDs: ownership.ownedTrinketIDs,
            ownedUniqueIDs: ownership.ownedUniqueIDs,
            goldFoundPercent: request.goldFoundPercent,
            materialsFoundPercent: request.materialsFoundPercent,
            astralChanceBonusPercent: astralChanceBonusPercent,
            using: &rng,
        )
    }

    static func grantedMaterials(
        override: [ResourceAmount]?,
        loot: BattleLootResult?,
        fallback: [ResourceAmount] = [],
    ) -> [ResourceAmount] {
        override ?? loot?.materials ?? fallback
    }

    static func grantedItem(
        override: InventoryItem?,
        loot: BattleLootResult?,
    ) -> InventoryItem? {
        override ?? loot?.item
    }

    static func grantVictoryRewards(
        hero: Combatant,
        companion: Combatant,
        encounterLevel: Int,
        stageGold: Int,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardAward? = nil,
        grantsCombatExperience: Bool = true,
        experienceEarnedPercent: Int = 0,
        materialRewards: [ResourceAmount],
        item: InventoryItem?,
        save: inout PlayerSave,
    ) {
        let resolved = award ?? BattleRewardPlan(
            stageGold: stageGold,
            goldFindPercent: save.homestead.effects.goldFindPercent,
            heroExperience: grantsCombatExperience ? battleExperienceAward(
                playerLevel: save.roster.progression(for: hero).level, enemyLevel: encounterLevel,
                highestLevel: save.roster.highestHeroLevel, experienceEarnedPercent: experienceEarnedPercent,
            ) : 0,
            companionExperience: grantsCombatExperience ? battleExperienceAward(
                playerLevel: save.roster.progression(for: companion).level, enemyLevel: encounterLevel,
                highestLevel: save.roster.highestCompanionLevel, experienceEarnedPercent: experienceEarnedPercent,
            ) : 0,
            materials: materialRewards, items: item.map { [$0] } ?? [],
        ).resolve(battleGold: battleGold)
        apply(resolved, hero: hero, companion: companion, save: &save)
    }

    public static func apply(
        _ award: BattleRewardAward,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
    ) {
        let now = Date()
        save.applyGoldDelta(award.goldDelta, at: now)
        save.roster.grantExperience(award.heroExperience, to: hero)
        save.roster.grantExperience(award.companionExperience, to: companion)
        save.grantMaterials(award.materials, at: now)
        for item in award.items {
            save.inventory.appendUniqueItem(item)
        }
    }
}
