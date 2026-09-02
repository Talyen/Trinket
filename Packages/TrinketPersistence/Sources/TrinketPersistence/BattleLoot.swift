import Foundation
import TrinketContent
import TrinketCore

public struct BattleLootPackage: Hashable, Sendable {
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
        .wood, .stone, .iron, .food, .herbs, .hide, .crystal,
    ]

    public static func quantityRange(forLevel level: Int) -> ClosedRange<Int> {
        let clamped = max(1, level)
        let minQty = 3 + (clamped * 9) / 49
        let maxQty = max(minQty, 4 + (clamped * 20) / 49)
        return minQty ... maxQty
    }

    public static func resolve(
        encounterLevel: Int,
        enemyIsBoss: Bool,
        itemID: String,
        keywordBias: Set<Keyword> = [],
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String>,
        goldFoundPercent: Int = 0,
        materialsFoundPercent: Int = 0,
        astralChanceBonusPercent: Int = 0,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> BattleLootPackage {
        let range = quantityRange(forLevel: encounterLevel)
        let multiplier = enemyIsBoss ? 2 : 1

        var gold = Int.random(in: range, using: &randomNumberGenerator) * multiplier
        gold = CombatRounding.scaled(gold, byPercent: goldFoundPercent)

        var materials = rollDistinctMaterials(
            count: 2,
            range: range,
            quantityMultiplier: multiplier,
            using: &randomNumberGenerator,
        )
        materials = materials.map {
            ResourceAmount($0.resource, CombatRounding.scaled($0.quantity, byPercent: materialsFoundPercent))
        }

        let tier = ItemRarityRoll.roll(
            bossContent: enemyIsBoss,
            astralChanceBonusPercent: astralChanceBonusPercent,
            using: &randomNumberGenerator,
        )
        let item = ItemRewardGenerator.generate(
            id: itemID,
            tier: tier,
            ownedTrinketIDs: ownedTrinketIDs,
            ownedUniqueIDs: ownedUniqueIDs,
            keywordBias: keywordBias,
            using: &randomNumberGenerator,
        )

        return BattleLootPackage(item: item, gold: gold, materials: materials)
    }

    public static func resolveJourney(
        stage: Stage,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String>,
        astralChanceBonusPercent: Int = 0,
    ) -> BattleLootPackage {
        VictoryRewardApplier.resolveLoot(
            LootRequest(seedSalt: "battle-loot-journey-\(stage.id)", itemID: "\(stage.id)-loot"),
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            worldSeed: worldSeed,
            ownership: RewardOwnership(
                ownedTrinketIDs: ownedTrinketIDs,
                ownedUniqueIDs: ownedUniqueIDs,
            ),
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    public static func resolveSpire(
        floor: SpireFloor,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        worldSeed: UInt64,
        keywordBias: Set<Keyword> = [],
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String>,
        astralChanceBonusPercent: Int = 0,
    ) -> BattleLootPackage {
        var combinedBias = keywordBias
        if let spire = GameContent.spire(id: floor.spireID) {
            combinedBias.insert(spire.keyword)
        }
        return VictoryRewardApplier.resolveLoot(
            LootRequest(
                seedSalt: "battle-loot-spire-\(floor.spireID.rawValue)-\(floor.floor)",
                itemID: "spire-\(floor.spireID.rawValue)-floor-\(floor.floor)-loot",
                keywordBias: combinedBias,
            ),
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            worldSeed: worldSeed,
            ownership: RewardOwnership(
                ownedTrinketIDs: ownedTrinketIDs,
                ownedUniqueIDs: ownedUniqueIDs,
            ),
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    public static func resolveLabyrinth(
        node: LabyrinthNode,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        effects: LabyrinthModifierEffects,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String>,
        astralChanceBonusPercent: Int = 0,
    ) -> BattleLootPackage {
        VictoryRewardApplier.resolveLoot(
            LootRequest(
                seedSalt: "battle-loot-labyrinth-\(node.id)",
                itemID: LabyrinthCompletion.rewardItemID(forNodeID: node.id),
                goldFoundPercent: effects.goldFoundPercent,
                materialsFoundPercent: effects.materialsFoundPercent,
            ),
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            worldSeed: worldSeed,
            ownership: RewardOwnership(
                ownedTrinketIDs: ownedTrinketIDs,
                ownedUniqueIDs: ownedUniqueIDs,
            ),
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    private static func rollDistinctMaterials(
        count: Int,
        range: ClosedRange<Int>,
        quantityMultiplier: Int,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> [ResourceAmount] {
        var pool = materialResources
        var picked: [ResourceAmount] = []
        for _ in 0 ..< count {
            guard !pool.isEmpty else { break }
            let index = Int.random(in: 0 ..< pool.count, using: &randomNumberGenerator)
            let resource = pool.remove(at: index)
            let quantity = Int.random(in: range, using: &randomNumberGenerator) * quantityMultiplier
            picked.append(ResourceAmount(resource, quantity))
        }
        return picked
    }
}
