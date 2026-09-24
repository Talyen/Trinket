import Foundation
import TrinketContent
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

enum BattleLoot {
    static let materialResources: [HomesteadResource] = [
        .wood, .stone, .iron, .food, .herbs, .hide, .gems,
    ]

    static func quantityRange(forLevel level: Int) -> ClosedRange<Int> {
        let clamped = max(1, level)
        let minQty = 3 + (clamped * 9) / 49
        let maxQty = max(minQty, 4 + (clamped * 20) / 49)
        return minQty ... maxQty
    }

    /// - Parameters:
    ///   - encounterLevel: fight-relative level driving gold/material
    ///     quantities (usually party-adjusted).
    ///   - rewardLevel: authored content level driving item tier chances
    ///     (never party-adjusted; see LootRequest).
    static func resolve(
        encounterLevel: Int,
        rewardLevel: Int,
        enemyIsBoss: Bool,
        itemID: String,
        keywordBias: Set<Keyword> = [],
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String>,
        goldFoundPercent: Int = 0,
        materialsFoundPercent: Int = 0,
        materialFocus: HomesteadResource? = nil,
        favoredItemTier: ItemDropTier? = nil,
        itemTierWeightBonusPercent: Int = 0,
        requiredItemTier: ItemDropTier? = nil,
        requiredBaseTypeIDs: Set<String>? = nil,
        requiredKeyword: Keyword? = nil,
        astralChanceBonusPercent: Int = 0,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> BattleLootResult {
        let range = quantityRange(forLevel: encounterLevel)
        let multiplier = enemyIsBoss ? 2 : 1

        var gold = Int.random(in: range, using: &randomNumberGenerator) * multiplier
        gold = CombatRounding.scaled(gold, byPercent: goldFoundPercent)

        var materials = rollDistinctMaterials(
            count: 2,
            range: range,
            quantityMultiplier: multiplier,
            focus: materialFocus,
            using: &randomNumberGenerator,
        )
        materials = materials.map {
            let bonus = materialFocus == nil || $0.resource == materialFocus ? materialsFoundPercent : 0
            return ResourceAmount($0.resource, CombatRounding.scaled($0.quantity, byPercent: bonus))
        }

        let eligibleBaseTypes = requiredBaseTypeIDs.map { ids in
            GameContent.itemBaseTypes.filter { ids.contains($0.id) }
        } ?? GameContent.itemBaseTypes
        precondition(!eligibleBaseTypes.isEmpty, "Guaranteed item family needs a matching base")
        let allowedTiers: Set<ItemDropTier> = if let requiredItemTier {
            [requiredItemTier]
        } else if requiredBaseTypeIDs != nil {
            [.basic, .astral]
        } else {
            Set(ItemDropTier.allCases)
        }
        let item = ItemRewardGenerator.generate(
            id: itemID,
            rewardLevel: rewardLevel,
            bossContent: enemyIsBoss,
            astralChanceBonusPercent: astralChanceBonusPercent,
            allowedTiers: allowedTiers,
            favoredTier: favoredItemTier,
            tierWeightBonusPercent: itemTierWeightBonusPercent,
            requiredKeyword: requiredKeyword,
            ownedTrinketIDs: ownedTrinketIDs,
            ownedUniqueIDs: ownedUniqueIDs,
            keywordBias: keywordBias,
            baseTypes: eligibleBaseTypes,
            using: &randomNumberGenerator,
        )

        return BattleLootResult(item: item, gold: gold, materials: materials)
    }

    private static func rollDistinctMaterials(
        count: Int,
        range: ClosedRange<Int>,
        quantityMultiplier: Int,
        focus: HomesteadResource?,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> [ResourceAmount] {
        var pool = materialResources
        var picked: [ResourceAmount] = []
        for _ in 0 ..< count {
            guard !pool.isEmpty else { break }
            let index: Int = if picked.isEmpty, let focus, let focusIndex = pool.firstIndex(of: focus) {
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
