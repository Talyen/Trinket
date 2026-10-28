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
        let x = Double(min(max(level, 1), 40) - 1) / 39
        return x * x * (3 - 2 * x)
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
            let hasTrinket = availableTiers.contains(.trinket)
            let hasUnique = availableTiers.contains(.unique)
            if hasTrinket, hasUnique {
                let uniqueChance = 0.05 + 0.45 * progress(level: level)
                return ItemDropTier.allCases.map { tier in
                    switch tier {
                    case .trinket: 1 - uniqueChance
                    case .unique: uniqueChance
                    case .basic, .astral: 0
                    }
                }
            }
            let collectible: ItemDropTier? = hasTrinket ? .trinket : hasUnique ? .unique : nil
            let guaranteed = collectible ?? (availableTiers.contains(.astral) ? .astral : nil)
            precondition(!availableTiers.isEmpty, "Item rewards require an eligible category.")
            return ItemDropTier.allCases.map { tier in
                if let guaranteed {
                    return tier == guaranteed ? 1 : 0
                }
                return availableTiers.contains(tier) ? 1 / Double(availableTiers.count) : 0
            }
        }
        let t = progress(level: level)
        var probabilities = ItemDropTier.allCases.map { tier in
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
        let total = probabilities.reduce(0, +)
        precondition(total > 0, "Item rewards require an eligible category.")
        for index in probabilities.indices {
            probabilities[index] /= total
        }
        guard collectibleChancePercent < 100,
              let gearIndex = ItemDropTier.allCases.firstIndex(where: {
                  ($0 == .basic || $0 == .astral) && availableTiers.contains($0)
              })
        else { return probabilities }
        // Scale actual chances after eligibility and bonuses, not raw weights.
        // Return the removed chance to Basic gear (Astral for Astral-only pools).
        // Clamp above 100: otherwise the gear share goes negative and the
        // distribution no longer sums to 1.
        let retained = Double(min(100, max(0, collectibleChancePercent))) / 100
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
