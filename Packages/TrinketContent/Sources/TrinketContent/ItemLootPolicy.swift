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
    static let curve: [(level: Int, weights: [Double])] = [
        (1, [98, 1.5, 0.4, 0.1]),
        (6, [90, 6, 3, 1]),
        (11, [80, 11, 6, 3]),
        (20, [70, 16, 9, 5]),
    ]

    static func probabilities(
        level: Int,
        bossContent: Bool,
        astralChanceBonusPercent: Int,
        availableTiers: Set<ItemDropTier>,
    ) -> [Double] {
        let level = min(max(level, curve[0].level), curve[curve.count - 1].level)
        let upperIndex = curve.firstIndex { $0.level >= level } ?? (curve.count - 1)
        let lower = curve[max(0, upperIndex - 1)]
        let upper = curve[upperIndex]
        let fraction = upper.level == lower.level ? 0 : Double(level - lower.level) / Double(upper.level - lower.level)
        let weights = ItemDropTier.allCases.enumerated().map { index, tier in
            guard availableTiers.contains(tier) else { return 0.0 }
            var weight = lower.weights[index] + (upper.weights[index] - lower.weights[index]) * fraction
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
