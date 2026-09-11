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
    static let bossPremiumMultiplier = 3.0
    static let minimumLevel = 1
    static let maximumLevel = 40
    static let baseWeights: [Double] = [98, 1.5, 0.4, 0.1]
    static let topWeights: [Double] = [60, 20, 12, 8]
    static let curvature: Double = 25

    static func progress(level: Int) -> Double {
        let clamped = Double(min(max(level, minimumLevel), maximumLevel) - minimumLevel)
        let span = Double(maximumLevel - minimumLevel)
        return (clamped / (curvature + clamped)) / (span / (curvature + span))
    }

    static func probabilities(
        level: Int,
        bossContent: Bool,
        astralChanceBonusPercent: Int,
        availableTiers: Set<ItemDropTier>,
    ) -> [Double] {
        let clampedLevel = min(max(level, minimumLevel), maximumLevel)
        let t = progress(level: clampedLevel)
        let weights = ItemDropTier.allCases.enumerated().map { index, tier in
            guard availableTiers.contains(tier) else { return 0.0 }
            var weight = baseWeights[index] + (topWeights[index] - baseWeights[index]) * t
            if bossContent, tier != .basic {
                weight *= bossPremiumMultiplier
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
