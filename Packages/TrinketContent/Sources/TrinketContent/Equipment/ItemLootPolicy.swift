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
        collectibleChancePercent: Int = 100,
    ) -> [Double] {
        if bossContent {
            let collectibles = availableTiers.intersection([.trinket, .unique])
            return ItemDropTier.allCases.map { tier in
                if collectibles.isEmpty {
                    return tier == .astral ? 1 : 0
                }
                return collectibles.contains(tier) ? 1 / Double(collectibles.count) : 0
            }
        }
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
        var probabilities = weights.map { $0 / total }
        guard collectibleChancePercent < 100,
              let gearIndex = ItemDropTier.allCases.firstIndex(where: {
                  ($0 == .basic || $0 == .astral) && availableTiers.contains($0)
              })
        else { return probabilities }
        // Scale actual chances after eligibility and bonuses, not raw weights.
        // Return the removed chance to Basic gear (Astral for Astral-only pools).
        let retained = Double(max(0, collectibleChancePercent)) / 100
        for (index, tier) in ItemDropTier.allCases.enumerated() where tier == .trinket || tier == .unique {
            probabilities[gearIndex] += probabilities[index] * (1 - retained)
            probabilities[index] *= retained
        }
        return probabilities
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
