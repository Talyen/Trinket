import Foundation
import TrinketCore

public struct BattleLootResult: Hashable, Sendable {
    public let item: InventoryItem
    public let gold: Int
    public let materials: [ResourceAmount]

    public init(item: InventoryItem, gold: Int, materials: [ResourceAmount]) {
        self.item = item
        self.gold = gold
        self.materials = materials
    }

    public var asStageReward: StageReward {
        StageReward(gold: gold, itemTemplateIDs: [], materialRewards: materials)
    }
}

public enum BattleLoot {
    static let materialResources: [HomesteadResource] = [
        .wood, .stone, .iron, .food, .herbs, .hide, .gems,
    ]

    public static func quantityRange(forLevel level: Int) -> ClosedRange<Int> {
        let clamped = max(1, level)
        // Divide first to retain the exact quantity without overflowing at high saved levels.
        let quotient = clamped / 49
        let remainder = clamped % 49
        let minQty = 3 + quotient * 9 + (remainder * 9) / 49
        let maxQty = max(minQty, 4 + quotient * 20 + (remainder * 20) / 49)
        return minQty ... maxQty
    }

    /// One captured encounter level drives currency quantities and item quality.
    public static func resolve(
        _ request: LootRequest,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        worldSeed: UInt64,
        ownership: RewardOwnership,
        astralChanceBonusPercent: Int = 0,
        wishedTemplateID: String? = nil,
        partyBias: PartyLootBias = PartyLootBias(),
    ) -> BattleLootResult {
        var rng = SeededRandomNumberGenerator(
            seed: GameContent.encounterSeed(worldSeed, salt: request.seedSalt),
        )
        let modifier = request.rewardModifier.map { ownership.resolved($0, enemyIsBoss: enemyIsBoss) }
        let additionalModifier = request.additionalRewardModifier?.resolved(
            ownedTrinketIDs: ownership.ownedTrinketIDs, ownedUniqueIDs: ownership.ownedUniqueIDs,
        )
        let itemModifier = modifier?.isItemFocused == true ? modifier
            : additionalModifier?.isItemFocused == true ? additionalModifier : nil
        var focuses: [HomesteadResource] = []
        if let f = modifier?.materialFocus, !focuses.contains(f) {
            focuses.append(f)
        }
        if let f = additionalModifier?.materialFocus, !focuses.contains(f) {
            focuses.append(f)
        }
        let range = quantityRange(forLevel: encounterLevel)
        let multiplier = enemyIsBoss ? 2 : 1

        var goldBonus = request.goldFoundPercent
        if let m = modifier {
            goldBonus += m.goldBonusPercent
        }
        if let a = additionalModifier {
            goldBonus += a.goldBonusPercent
        }
        var gold = Int.random(in: range, using: &rng) * multiplier
        gold = CombatRounding.scaled(gold, byPercent: goldBonus)

        var materials = rollDistinctMaterials(
            range: range,
            quantityMultiplier: multiplier,
            focuses: focuses,
            using: &rng,
        )
        materials = materials.map { material in
            var bonus = request.materialsFoundPercent
            bonus += Self.materialBonus(modifier, for: material.resource)
            bonus += Self.materialBonus(additionalModifier, for: material.resource)
            return ResourceAmount(material.resource, CombatRounding.scaled(material.quantity, byPercent: bonus))
        }

        let item = rollItem(
            request, modifier: itemModifier, encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss, ownership: ownership,
            astralChanceBonusPercent: astralChanceBonusPercent, wishedTemplateID: wishedTemplateID, partyBias: partyBias, using: &rng,
        )

        return BattleLootResult(item: item, gold: gold, materials: materials)
    }

    static func rollItem(
        _ request: LootRequest,
        modifier: RewardModifier?,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        ownership: RewardOwnership,
        astralChanceBonusPercent: Int,
        excludesBasic: Bool = false,
        wishedTemplateID: String? = nil,
        partyBias: PartyLootBias = PartyLootBias(),
        using rng: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        let modifier = enemyIsBoss ? nil : modifier
        let requiredBaseTypeIDs = modifier?.requiredBaseTypeIDs
        let eligibleBaseTypes = requiredBaseTypeIDs.map { ids in
            GameContent.itemBaseTypes.filter { ids.contains($0.id) }
        } ?? GameContent.itemBaseTypes
        // An unknown base family degrades to the full gear pool instead of
        // trapping the live loot roll.
        let resolvedBaseTypes = eligibleBaseTypes.isEmpty ? GameContent.itemBaseTypes : eligibleBaseTypes
        let guaranteesTrinket = enemyIsBoss && request.guaranteesTrinket
            && GameContent.trinketItems.contains { !ownership.ownedTrinketIDs.contains($0.templateID) }
        var allowedTiers: Set<ItemDropTier> = if guaranteesTrinket {
            [.trinket]
        } else if let tier = modifier?.requiredItemTier {
            [tier]
        } else if requiredBaseTypeIDs != nil {
            [.basic, .astral]
        } else {
            Set(ItemDropTier.allCases)
        }
        if enemyIsBoss || excludesBasic {
            allowedTiers.remove(.basic)
        }
        return ItemRewardGenerator.generate(
            id: request.itemID,
            rewardLevel: max(1, encounterLevel),
            bossContent: enemyIsBoss,
            astralChanceBonusPercent: astralChanceBonusPercent,
            allowedTiers: allowedTiers,
            favoredTier: modifier?.favoredItemTier,
            tierWeightBonusPercent: modifier?.favoredItemTier != nil ? RewardModifier.rareTierWeightBonusPercent : 0,
            wishedTemplateID: wishedTemplateID,
            requiredKeyword: modifier?.requiredKeyword,
            ownedTrinketIDs: ownership.ownedTrinketIDs,
            ownedUniqueIDs: ownership.ownedUniqueIDs,
            keywordBias: enemyIsBoss ? [] : request.keywordBias,
            partyBias: partyBias,
            baseTypes: resolvedBaseTypes,
            using: &rng,
        )
    }

    private static func materialBonus(_ modifier: RewardModifier?, for resource: HomesteadResource) -> Int {
        guard let modifier, modifier == .materials || modifier.materialFocus == resource else { return 0 }
        return RewardModifier.bonusPercent
    }

    private static func rollDistinctMaterials(
        range: ClosedRange<Int>,
        quantityMultiplier: Int,
        focuses: [HomesteadResource],
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> [ResourceAmount] {
        var pool = materialResources
        var picked: [ResourceAmount] = []
        for slot in 0 ..< 2 {
            let index: Int = if focuses.indices.contains(slot), let focusIndex = pool.firstIndex(of: focuses[slot]) {
                focusIndex
            } else {
                Int.random(in: 0 ..< pool.count, using: &randomNumberGenerator)
            }
            let resource = pool.remove(at: index)
            let quantity = Int.random(in: range, using: &randomNumberGenerator) * quantityMultiplier
            picked.append(ResourceAmount(resource, quantity))
        }
        return picked
    }
}
