import Foundation

/// Pure battle-rule formulas derived from a combatant's `PrimaryStats`. These
/// are intentionally side-effect-free so they can be tested without standing up
/// a `BattleState`.
public extension PrimaryStats {
    /// Bonus added to a damage roll for the given `keyword`. Mirrors the
    /// prior `BattleState.statBonusForDamage(from:keyword:)` formula.
    public func statBonusForDamage(keyword: Keyword) -> Int {
        switch keyword {
        case .physical, .stun: return strength / 5
        case .bleed: return agility / 5
        case .burn, .freeze: return intellect / 5
        case .poison, .holy, .nature: return wisdom / 5
        default: return 0
        }
    }

    /// Probability that an incoming attack is dodged. Capped at 75%.
    /// Mirrors the prior `BattleState.dodgeChance(for:)` formula.
    public var dodgeChance: Double {
        min(0.75, 0.05 + Double(agility) * 0.005)
    }

    /// Percentage of incoming damage absorbed passively by toughness, as a
    /// fraction in `[0, 1)`. Mirrors the prior
    /// `BattleState.toughnessMitigationPct(for:)` formula.
    public var toughnessMitigationPct: Double {
        let t = Double(toughness)
        return t / (t + 50.0)
    }

    /// Multiplier applied to damage-over-time ticks. Capped at 0.25 so
    /// high-toughness targets still take some chip damage. Mirrors the prior
    /// `BattleState.dotResistanceMultiplier(for:)` formula.
    public var dotResistanceMultiplier: Double {
        max(0.25, 1.0 - Double(toughness) * 0.005)
    }
}
