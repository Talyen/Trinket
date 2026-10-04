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
        let clamped = Double(min(max(level, 1), 40) - 1)
        let span = 39.0
        let curvature = 25.0
        return (clamped / (curvature + clamped)) / (span / (curvature + span))
    }

    static func probabilities(
        level: Int,
        bossContent: Bool,
        astralChanceBonusPercent: Int,
        availableTiers: Set<ItemDropTier>,
        favoredTier: ItemDropTier? = nil,
        tierWeightBonusPercent: Int = 0,
    ) -> [Double] {
        let t = progress(level: level)
        let weights = ItemDropTier.allCases.map { tier in
            guard availableTiers.contains(tier) else { return 0.0 }
            let endpoints: (base: Double, top: Double) = switch tier {
            case .basic: (98, 60)
            case .astral: (1.5, 20)
            case .trinket: (0.4, 12)
            case .unique: (0.1, 8)
            }
            var weight = endpoints.base + (endpoints.top - endpoints.base) * t
            if bossContent, tier != .basic {
                weight *= 3
            }
            if tier == .astral {
                weight *= 1 + Double(max(0, astralChanceBonusPercent)) / 100
            }
            if tier == favoredTier {
                weight *= 1 + Double(max(0, tierWeightBonusPercent)) / 100
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
