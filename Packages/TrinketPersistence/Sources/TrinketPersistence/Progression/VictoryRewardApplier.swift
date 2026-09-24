import Foundation
import TrinketContent
import TrinketCore

public struct LootRequest: Equatable, Sendable {
    /// Legacy request field retained for call sites; item generation uses the
    /// captured `encounterLevel` passed to `resolveLoot`. That level also drives
    /// fight-relative XP, Gold, and material quantities.
    public var rewardLevel: Int
    public var seedSalt: String
    public var itemID: String
    public var keywordBias: Set<Keyword>
    public var goldFoundPercent: Int
    public var materialsFoundPercent: Int
    public var rewardModifier: RewardModifier?

    public init(
        rewardLevel: Int,
        seedSalt: String,
        itemID: String,
        keywordBias: Set<Keyword> = [],
        goldFoundPercent: Int = 0,
        materialsFoundPercent: Int = 0,
        rewardModifier: RewardModifier? = nil,
    ) {
        self.rewardLevel = rewardLevel
        self.seedSalt = seedSalt
        self.itemID = itemID
        self.keywordBias = keywordBias
        self.goldFoundPercent = goldFoundPercent
        self.materialsFoundPercent = materialsFoundPercent
        self.rewardModifier = rewardModifier
    }
}

public struct RewardOwnership: Equatable, Sendable {
    public var eligibleModifiers: [RewardModifier] {
        RewardModifier.eligible(ownedTrinketIDs: ownedTrinketIDs, ownedUniqueIDs: ownedUniqueIDs)
    }

    public func modifiers(ids: [LabyrinthModifierID]) -> [LabyrinthModifierDefinition] {
        LabyrinthCatalog.modifiers(ids: ids, eligibleRewards: eligibleModifiers)
    }

    public var ownedTrinketIDs: Set<String>
    public var ownedUniqueIDs: Set<String>

    public init(ownedTrinketIDs: Set<String> = [], ownedUniqueIDs: Set<String> = []) {
        self.ownedTrinketIDs = ownedTrinketIDs
        self.ownedUniqueIDs = ownedUniqueIDs
    }

    public init(_ inventory: PlayerInventoryState) {
        self.init(ownedTrinketIDs: inventory.ownedTrinketIDs, ownedUniqueIDs: inventory.ownedUniqueIDs)
    }

    public init(_ save: PlayerSave) {
        self.init(save.inventory)
    }
}

public extension LootRequest {
    static func journey(stage: Stage, chapters: [Chapter] = GameContent.chapters) -> LootRequest {
        LootRequest(
            rewardLevel: StageCompletion.resolvedEncounterLevel(for: stage, in: chapters),
            seedSalt: "battle-loot-journey-\(stage.id)",
            itemID: "\(stage.id)-loot",
        )
    }

    static func spire(floor: SpireFloor) -> LootRequest {
        var keywordBias: Set<Keyword> = []
        if let spire = GameContent.spire(id: floor.spireID) {
            keywordBias.insert(spire.keyword)
        }
        return LootRequest(
            rewardLevel: EncounterLevelResolver.spireEnemyLevel(for: floor),
            seedSalt: "battle-loot-spire-\(floor.spireID.rawValue)-\(floor.floor)",
            itemID: "spire-\(floor.spireID.rawValue)-floor-\(floor.floor)-loot",
            keywordBias: keywordBias,
        )
    }

    static func labyrinth(node: LabyrinthNode, effects: LabyrinthModifierEffects) -> LootRequest {
        LootRequest(
            rewardLevel: EncounterLevelResolver.labyrinthEnemyLevel(for: node),
            seedSalt: "battle-loot-labyrinth-\(node.id)",
            itemID: LabyrinthCompletion.rewardItemID(forNodeID: node.id),
            goldFoundPercent: effects.goldFoundPercent - (effects.rewardModifier?.goldBonusPercent ?? 0),
            materialsFoundPercent: effects.materialsFoundPercent - (effects.rewardModifier?.materialsBonusPercent ?? 0),
            rewardModifier: effects.rewardModifier,
        )
    }

    static func voyage(node: VoyageNode, rewardLevel: Int, effects: LabyrinthModifierEffects) -> LootRequest {
        LootRequest(
            rewardLevel: rewardLevel, seedSalt: node.id, itemID: "voyage-\(node.id)",
            goldFoundPercent: effects.goldFoundPercent - (effects.rewardModifier?.goldBonusPercent ?? 0),
            materialsFoundPercent: effects.materialsFoundPercent - (effects.rewardModifier?.materialsBonusPercent ?? 0),
            rewardModifier: effects.rewardModifier,
        )
    }

    /// Fourth loot-request factory, co-located with the other three so a
    /// seed/level change touches one extension instead of four call sites.
    static func contract(
        offerID: String, rewardLevel: Int, modifier: RewardModifier = .gold,
    ) -> LootRequest {
        LootRequest(
            rewardLevel: rewardLevel,
            seedSalt: "battle-loot-contract-\(offerID)",
            itemID: "contract-\(offerID)-loot",
            rewardModifier: modifier,
        )
    }
}

public enum VictoryRewardApplier {
    public static func isBoss(enemyID: String?) -> Bool {
        guard let enemyID else { return false }
        return GameContent.enemy(matching: enemyID)?.isBoss == true
    }

    /// Single party-adjusted level truth. Authored levels stay fixed for item
    /// tiers (`LootRequest.rewardLevel`); fight-relative scaling (XP/gold/
    /// materials) adjusts by party average. Replaces the four per-mode copies.
    public static func partyAdjustedEncounterLevel(authoredLevel: Int, save: PlayerSave) -> Int {
        EncounterLevelResolver.campaignAdjusted(
            authoredLevel,
            partyAverageLevel: save.roster.activePartyAverageLevel,
        )
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleGold: BattleGoldFlow,
        goldFoundPercent: Int,
        goldFindFlat: Int = 0,
    ) -> Int {
        BattleRewardPlan(
            stageGold: stageGold, goldFindPercent: goldFoundPercent, goldFindFlat: goldFindFlat,
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
            goldFindFlat: homestead.effects.goldFindFlat,
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
        let modifier = request.rewardModifier?.resolved(
            ownedTrinketIDs: ownership.ownedTrinketIDs, ownedUniqueIDs: ownership.ownedUniqueIDs,
        )
        return BattleLoot.resolve(
            encounterLevel: encounterLevel,
            rewardLevel: max(1, encounterLevel),
            enemyIsBoss: enemyIsBoss,
            itemID: request.itemID,
            keywordBias: request.keywordBias,
            ownedTrinketIDs: ownership.ownedTrinketIDs,
            ownedUniqueIDs: ownership.ownedUniqueIDs,
            goldFoundPercent: request.goldFoundPercent + (modifier?.goldBonusPercent ?? 0),
            materialsFoundPercent: request.materialsFoundPercent + (modifier?.materialsBonusPercent ?? 0),
            materialFocus: modifier?.materialFocus,
            favoredItemTier: modifier?.favoredItemTier,
            itemTierWeightBonusPercent: modifier?.favoredItemTier != nil ? RewardModifier.rareTierWeightBonusPercent : 0,
            requiredItemTier: modifier?.requiredItemTier,
            requiredBaseTypeIDs: modifier?.requiredBaseTypeIDs,
            requiredKeyword: modifier?.requiredKeyword,
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

    /// Applies a battle's rewards. A pre-settled `award` from the battle that
    /// just ran wins by design: it snapshots homestead production at battle
    /// end, and re-settling at completion would accrue production a second
    /// time. Callers without a battle pass nil to settle fresh.
    ///
    /// A duplicate headline item (owned trinket/unique) converts to
    /// level-scaled consolation gold instead of granting nothing: the
    /// encounter still marks complete, so the claim must still pay something.
    static func grantVictoryRewards(
        hero: Combatant,
        companion: Combatant,
        encounterLevel: Int,
        stageGold: Int,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        grantsCombatExperience: Bool = true,
        experienceEarnedPercent: Int = 0,
        materialRewards: [ResourceAmount],
        item: InventoryItem?,
        save: inout PlayerSave,
    ) {
        var payableItem = item
        var consolationGold = 0
        if let candidate = item,
           InventoryDuplicatePolicy.containsDuplicate(of: candidate, in: save.inventory.items) {
            payableItem = nil
            let range = BattleLoot.quantityRange(forLevel: encounterLevel)
            consolationGold = (range.lowerBound + range.upperBound) / 2
        }
        let resolved = award ?? BattleRewardPlan(
            stageGold: stageGold + consolationGold,
            goldFindPercent: save.homestead.effects.goldFindPercent,
            goldFindFlat: save.homestead.effects.goldFindFlat,
            gemsFindBonus: save.homestead.effects.gemsFindBonus,
            goldOverflowExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: encounterLevel, roster: save.roster, percent: experienceEarnedPercent,
            ),
            heroExperience: grantsCombatExperience ? battleExperienceAward(
                playerLevel: save.roster.progression(for: hero).level, enemyLevel: encounterLevel,
                highestLevel: save.roster.highestHeroLevel, experienceEarnedPercent: experienceEarnedPercent,
            ) + save.homestead.effects.experienceBonus : 0,
            companionExperience: grantsCombatExperience ? battleExperienceAward(
                playerLevel: save.roster.progression(for: companion).level, enemyLevel: encounterLevel,
                highestLevel: save.roster.highestCompanionLevel, experienceEarnedPercent: experienceEarnedPercent,
            ) + save.homestead.effects.experienceBonus : 0,
            materials: materialRewards, items: payableItem.map { [$0] } ?? [],
        ).settle(
            battleGold: battleGold,
            inputs: RewardSettlementInputs(save: save, hero: hero, companion: companion),
        )
        apply(resolved, hero: hero, companion: companion, save: &save)
        if grantsCombatExperience {
            save.contracts.recordVictory(encounterLevel: encounterLevel)
        }
    }

    /// Applies a settled award verbatim. Dupe conversion happens at plan
    /// construction in `grantVictoryRewards` (nil-award path); battle-end
    /// awards carry launch-filtered items, so direct `apply` callers must
    /// filter duplicates first.
    public static func apply(
        _ settlement: BattleRewardSettlement,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
    ) {
        let award = settlement.award
        let now = settlement.inputs.productionDate
        save.applyGoldDelta(award.goldDelta, at: now)
        BattleExperienceReward.apply(settlement, hero: hero, companion: companion, save: &save)
        save.grantMaterials(award.materials, at: now)
        for item in award.items {
            save.inventory.appendUniqueItem(item)
        }
    }
}
