import Foundation

/// Pure battle-rule formulas derived from a combatant's `PrimaryStats`. These
/// are intentionally side-effect-free so they can be tested without standing up
/// a `BattleState`.
public extension PrimaryStats {
    /// Pure diminishing returns curve formula: stat / (stat + 80).
    /// Returns a value between 0.0 (0%) and 1.0 (100%).
    static func diminishingReturnsPercent(for statValue: Int) -> Double {
        guard statValue > 0 else { return 0.0 }
        return Double(statValue) / (Double(statValue) + 80.0)
    }

    /// Pure diminishing returns curve formula applied to instance stat value.
    func diminishingReturnsPercent(for statValue: Int) -> Double {
        Self.diminishingReturnsPercent(for: statValue)
    }

    /// Outgoing damage scaling percentage bonus derived from primary stats
    /// using the diminishing returns curve.
    func statDamageBonusPercent(keyword: Keyword) -> Double {
        switch keyword {
        case .physical, .stun:
            diminishingReturnsPercent(for: strength)
        case .bleed:
            diminishingReturnsPercent(for: agility)
        case .burn, .freeze:
            diminishingReturnsPercent(for: intellect)
        case .poison, .holy:
            diminishingReturnsPercent(for: wisdom)
        default:
            0.0
        }
    }

    /// Probability that an incoming attack is dodged, capped at 75%.
    /// Scales with Agility using the diminishing returns curve.
    var dodgeChance: Double {
        min(0.75, diminishingReturnsPercent(for: agility))
    }

    /// Percentage damage reduction from Toughness using the diminishing returns curve.
    var toughnessMitigationPercent: Double {
        diminishingReturnsPercent(for: toughness)
    }

    /// Stun/freeze control-meter buildup threshold for a combatant with the given
    /// effective max health (`base max + toughness`). Scales with Agility using
    /// the diminishing returns curve.
    func controlMeterThreshold(baseMaxHealth: Int) -> Int {
        let baseThreshold = Double(baseMaxHealth) * 0.20
        let agilityResist = 1.0 + diminishingReturnsPercent(for: agility)
        return max(1, Int(ceil(baseThreshold * agilityResist)))
    }

    /// Base critical-hit chance for the given keyword, before ability or item
    /// bonuses. Capped at 75%. Keywords that do not allow criticals return 0.
    /// Scales using the primary stat diminishing returns curve.
    func criticalChance(for keyword: Keyword) -> Double {
        guard keyword.allowsCriticalHits else { return 0 }
        let statBonus: Double = switch keyword {
        case .physical, .bleed, .stun:
            diminishingReturnsPercent(for: agility)
        case .burn, .freeze:
            diminishingReturnsPercent(for: intellect)
        case .poison, .holy, .health, .leech:
            diminishingReturnsPercent(for: wisdom)
        default:
            0.0
        }
        return min(0.75, statBonus)
    }
}
