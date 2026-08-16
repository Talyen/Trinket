import Foundation
import TrinketContent
import TrinketCore

/// Deterministic combat victory loot: 1 generated item, gold, and exactly 2 materials.
public struct BattleLootPackage: Hashable, Sendable {
    public let item: InventoryItem
    public let gold: Int
    public let materials: [ResourceAmount]

    public init(item: InventoryItem, gold: Int, materials: [ResourceAmount]) {
        self.item = item
        self.gold = gold
        self.materials = materials
    }

    /// Display/grant DTO used by battle chrome and completion overrides.
    public var asStageReward: StageReward {
        StageReward(gold: gold, itemTemplateIDs: [], materialRewards: materials)
    }
}

public enum BattleLoot {
    public static let materialResources: [HomesteadResource] = [
        .wood, .stone, .iron, .food, .herbs, .hide, .crystal,
    ]

    /// Shared quantity band for gold and each material (L1 3–4 → L50 12–24).
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
        goldPercent: Int = 0,
        astralChanceBonusPercent: Int = 0,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> BattleLootPackage {
        let range = quantityRange(forLevel: encounterLevel)
        let multiplier = enemyIsBoss ? 2 : 1

        var gold = Int.random(in: range, using: &randomNumberGenerator) * multiplier
        if goldPercent != 0 {
            gold = max(0, gold + (gold * goldPercent) / 100)
        }

        let materials = rollDistinctMaterials(
            count: 2,
            range: range,
            quantityMultiplier: multiplier,
            using: &randomNumberGenerator
        )

        let rarity: Rarity = if enemyIsBoss {
            .astral
        } else if astralChanceBonusPercent > 0 {
            ItemRarityRoll.roll(
                baseAstralChancePercent: 0,
                astralChanceBonusPercent: astralChanceBonusPercent,
                using: &randomNumberGenerator
            )
        } else {
            .basic
        }
        let item = ItemRewardGenerator.generate(
            id: itemID,
            rarity: rarity,
            ownedTrinketIDs: ownedTrinketIDs,
            keywordBias: keywordBias,
            using: &randomNumberGenerator
        )

        return BattleLootPackage(item: item, gold: gold, materials: materials)
    }

    /// Journey combat loot; seed is stable per save + stage so victory chrome matches claim.
    public static func resolveJourney(
        stage: Stage,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage {
        var rng = SeededRandomNumberGenerator(
            seed: GameContent.encounterSeed(worldSeed, salt: "battle-loot-journey-\(stage.id)")
        )
        return resolve(
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            itemID: "\(stage.id)-loot",
            ownedTrinketIDs: ownedTrinketIDs,
            astralChanceBonusPercent: astralChanceBonusPercent,
            using: &rng
        )
    }

    /// Spire floor loot; optional keyword bias from the Spire.
    public static func resolveSpire(
        floor: SpireFloor,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        worldSeed: UInt64,
        keywordBias: Set<Keyword> = [],
        ownedTrinketIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage {
        var rng = SeededRandomNumberGenerator(
            seed: GameContent.encounterSeed(
                worldSeed,
                salt: "battle-loot-spire-\(floor.spireID.rawValue)-\(floor.floor)"
            )
        )
        return resolve(
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            itemID: "spire-\(floor.spireID.rawValue)-floor-\(floor.floor)-loot",
            keywordBias: keywordBias,
            ownedTrinketIDs: ownedTrinketIDs,
            astralChanceBonusPercent: astralChanceBonusPercent,
            using: &rng
        )
    }

    /// Labyrinth combat loot; incorporates world seed + node id.
    public static func resolveLabyrinth(
        node: LabyrinthNode,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        effects: LabyrinthModifierEffects,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage {
        var rng = SeededRandomNumberGenerator(
            seed: GameContent.encounterSeed(worldSeed, salt: "battle-loot-labyrinth-\(node.id)")
        )
        return resolve(
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            itemID: "labyrinth-\(node.id)",
            keywordBias: effects.keywordBiases,
            ownedTrinketIDs: ownedTrinketIDs,
            goldPercent: effects.goldPercent,
            astralChanceBonusPercent: effects.astralChanceBonusPercent + astralChanceBonusPercent,
            using: &rng
        )
    }

    private static func rollDistinctMaterials(
        count: Int,
        range: ClosedRange<Int>,
        quantityMultiplier: Int,
        using randomNumberGenerator: inout some RandomNumberGenerator
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
