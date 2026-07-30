import Foundation

/// Pure battle-rule formulas derived from a combatant's `PrimaryStats`. These
/// are intentionally side-effect-free so they can be tested without standing up
/// a `BattleState`.
public extension PrimaryStats {
    /// Player / companion soft cap for dodge and crit after contest + bonuses.
    static let playerChanceCap: Double = 0.75

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

    /// Contested dodge: defender agility minus attacker agility (accuracy), floored at 0.
    /// Soft-cap is applied by the caller (player 75% / enemy archetype caps).
    func contestedDodgeChance(againstAttackerAgility attackerAgility: Int) -> Double {
        max(
            0,
            diminishingReturnsPercent(for: agility) - diminishingReturnsPercent(for: attackerAgility)
        )
    }

    /// Percentage damage reduction from Toughness using the diminishing returns curve.
    var toughnessMitigationPercent: Double {
        diminishingReturnsPercent(for: toughness)
    }

    /// Stun/freeze control-meter buildup threshold for a combatant with the given
    /// effective max health (`base max + toughness`). Scales with Agility using
    /// the diminishing returns curve.
    func controlMeterThreshold(baseMaxHealth: Int) -> Int {
        let agilityResist = 1.0 + diminishingReturnsPercent(for: agility)
        return max(1, CombatRounding.rounded(Double(baseMaxHealth) * 0.20 * agilityResist))
    }

    /// Contested critical-hit chance for the given keyword: attacker keyword stat
    /// minus defender toughness, floored at 0. Soft-cap is applied by the caller.
    /// Keywords that do not allow criticals return 0.
    func contestedCriticalChance(
        for keyword: Keyword,
        againstDefenderToughness defenderToughness: Int
    ) -> Double {
        guard keyword.allowsCriticalHits else { return 0 }
        let attackCurve: Double = switch keyword {
        case .physical, .bleed, .stun:
            diminishingReturnsPercent(for: agility)
        case .burn, .freeze:
            diminishingReturnsPercent(for: intellect)
        case .poison, .holy, .health, .leech:
            diminishingReturnsPercent(for: wisdom)
        default:
            0.0
        }
        return max(0, attackCurve - diminishingReturnsPercent(for: defenderToughness))
    }
}

public extension GrowthArchetype {
    /// Soft cap on contested dodge chance when this archetype is an enemy.
    var enemyDodgeChanceCap: Double {
        switch self {
        case .assassin: 0.35
        case .bruiser: 0.25
        case .mage, .tank, .support: 0.15
        }
    }

    /// Soft cap on contested crit chance when this archetype is an enemy.
    var enemyCriticalChanceCap: Double {
        switch self {
        case .assassin: 0.35
        case .bruiser, .mage: 0.30
        case .tank, .support: 0.20
        }
    }
}
