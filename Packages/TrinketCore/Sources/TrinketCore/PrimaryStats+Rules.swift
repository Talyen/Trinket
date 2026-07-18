import Foundation

/// Pure battle-rule formulas derived from a combatant's `PrimaryStats`. These
/// are intentionally side-effect-free so they can be tested without standing up
/// a `BattleState`.
public extension PrimaryStats {
    /// Bonus added to a damage roll for the given `keyword`. Mirrors the
    /// prior `BattleState.statBonusForDamage(from:keyword:)` formula.
    func statBonusForDamage(keyword: Keyword) -> Int {
        switch keyword {
        case .physical, .stun: strength / 5
        case .bleed: agility / 5
        case .burn, .freeze: intellect / 5
        case .poison, .holy: wisdom / 5
        default: 0
        }
    }

    /// Probability that an incoming attack is dodged. Capped at 75%.
    /// Scales with Agility at the same per-point rate as critical chance.
    var dodgeChance: Double {
        min(0.75, 0.05 + Double(agility) * 0.0025)
    }

    /// Flat Armor effectiveness bonus from Toughness. Mirrors the damage-stat
    /// `/ 5` pattern used by Strength / Agility / Intellect / Wisdom.
    var armorEffectivenessBonus: Int {
        toughness / 5
    }

    /// Stun/freeze control-meter buildup threshold for a combatant with the given
    /// effective max health (`base max + toughness`). Mirrors the prior
    /// `ControlMeterEngine` / roster max-health formula.
    func controlMeterThreshold(baseMaxHealth: Int) -> Int {
        let baseThreshold = Double(baseMaxHealth) * 0.20
        let agilityResist = 1.0 + Double(agility) * 0.01
        return max(1, Int(ceil(baseThreshold * agilityResist)))
    }

    /// Base critical-hit chance for the given keyword, before ability or item
    /// bonuses. Capped at 75%. Keywords that do not allow criticals return 0.
    func criticalChance(for keyword: Keyword) -> Double {
        guard keyword.allowsCriticalHits else { return 0 }
        let statBonus: Double = switch keyword {
        case .physical, .bleed, .stun:
            Double(agility) * 0.0025
        case .burn, .freeze:
            Double(intellect) * 0.0025
        case .poison, .holy, .health, .leech:
            Double(wisdom) * 0.0025
        default:
            0
        }
        return min(0.75, 0.05 + statBonus)
    }
}
