public enum ItemDropTier: String, CaseIterable, Sendable {
    case basic
    case astral
    case trinket
    case unique

    public var id: String {
        rawValue
    }
}

enum ItemLootPolicy {
    static func progress(level: Int) -> Double {
        let clamped = Double(min(max(level, LootTuning.minimumLevel), LootTuning.maximumLevel) - LootTuning.minimumLevel)
        let span = Double(LootTuning.maximumLevel - LootTuning.minimumLevel)
        return (clamped / (LootTuning.curvature + clamped)) / (span / (LootTuning.curvature + span))
    }

    static func probabilities(
        level: Int,
        bossContent: Bool,
        astralChanceBonusPercent: Int,
        availableTiers: Set<ItemDropTier>,
    ) -> [Double] {
        let clampedLevel = min(max(level, LootTuning.minimumLevel), LootTuning.maximumLevel)
        let t = progress(level: clampedLevel)
        let weights = ItemDropTier.allCases.enumerated().map { index, tier in
            guard availableTiers.contains(tier) else { return 0.0 }
            var weight = LootTuning.baseWeights[index] + (LootTuning.topWeights[index] - LootTuning.baseWeights[index]) * t
            if bossContent, tier != .basic {
                weight *= LootTuning.bossPremiumMultiplier
            }
            if tier == .astral {
                weight *= 1 + Double(max(0, astralChanceBonusPercent)) / 100
            }
            return weight
        }
        let total = weights.reduce(0, +)
        precondition(total > 0, "Item rewards require an eligible category.")
        return weights.map { $0 / total }
    }

    static func roll(probabilities: [Double], using randomNumberGenerator: inout some RandomNumberGenerator) -> ItemDropTier {
        let draw = Double.random(in: 0 ..< 1, using: &randomNumberGenerator)
        var cumulative = 0.0
        var last = ItemDropTier.basic
        for (tier, probability) in zip(ItemDropTier.allCases, probabilities) where probability > 0 {
            last = tier
            cumulative += probability
            if draw < cumulative {
                return tier
            }
        }
        return last
    }
}
