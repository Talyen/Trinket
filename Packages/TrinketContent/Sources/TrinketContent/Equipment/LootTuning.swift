import Foundation
import TrinketCore

/// Single surface for loot tuning knobs owned by TrinketContent. Values are
/// unchanged; the next balance pass touches this file instead of hunting
/// across the generators.
///
/// Out of scope on purpose: `ShopOfferGenerator` pricing (public API),
/// `BattleLoot` currency quantities (TrinketPersistence), and simulation
/// affix counts/levels (BattleEngine) live with their owners.
enum LootTuning {
    // MARK: - Tier odds (ItemLootPolicy)

    static let bossPremiumMultiplier = 3.0
    static let minimumLevel = 1
    static let maximumLevel = 40
    static let baseWeights: [Double] = [98, 1.5, 0.4, 0.1]
    static let topWeights: [Double] = [60, 20, 12, 8]
    static let curvature: Double = 25

    // MARK: - Affix counts (ItemGenerator.affixCount)

    /// Basic rarity: 80% one affix, else two.
    static let basicSingleAffixPercent = 80
    /// Astral rarity: 75% three affixes, else four.
    static let astralTripleAffixPercent = 75
    static let basicAffixCounts = (single: 1, double: 2)
    static let astralAffixCounts = (triple: 3, quad: 4)

    // MARK: - Keyword bias (ItemGenerator.adjustedWeight)

    /// Per-affix weight multiplier is `biasWeightBase + overlap`.
    static let biasWeightBase = 2
}
