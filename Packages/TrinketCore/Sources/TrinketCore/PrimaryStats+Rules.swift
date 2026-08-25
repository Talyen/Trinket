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

    /// Outgoing damage scaling percentage bonus derived from primary stats
    /// using the diminishing returns curve.
    func statDamageBonusPercent(keyword: Keyword) -> Double {
        switch keyword {
        case .physical, .stun:
            Self.diminishingReturnsPercent(for: strength)
        case .bleed:
            Self.diminishingReturnsPercent(for: agility)
        case .burn, .freeze:
            Self.diminishingReturnsPercent(for: intellect)
        case .poison, .holy:
            Self.diminishingReturnsPercent(for: wisdom)
        default:
            0.0
        }
    }

    /// Contested dodge: defender agility minus attacker agility (accuracy), floored at 0.
    /// Soft-cap is applied by the caller (player 75% / enemy archetype caps).
    func contestedDodgeChance(againstAttackerAgility attackerAgility: Int) -> Double {
        max(
            0,
            Self.diminishingReturnsPercent(for: agility) - Self.diminishingReturnsPercent(for: attackerAgility)
        )
    }

    /// Rational falloff constant for enemy dodge. Each point of contested dodge is
    /// divided by `1 + falloff * base`, so high dodge compresses harder while low
    /// dodge is barely affected, and the curve self-saturates at `1/falloff`.
    static let enemyDodgeFalloffConstant: Double = 4.0

    /// Contested dodge for an enemy defender: same agility contest as
    /// `contestedDodgeChance`, then compressed with the enemy falloff so steeper
    /// diminishing returns apply as the chance grows.
    func contestedEnemyDodgeChance(againstAttackerAgility attackerAgility: Int) -> Double {
        let base = max(
            0,
            Self.diminishingReturnsPercent(for: agility) - Self.diminishingReturnsPercent(for: attackerAgility)
        )
        return max(0, base / (1.0 + Self.enemyDodgeFalloffConstant * base))
    }

    /// Percentage damage reduction from Toughness using the diminishing returns curve.
    var toughnessMitigationPercent: Double {
        Self.diminishingReturnsPercent(for: toughness)
    }

    /// Stun/freeze control-meter buildup threshold for a combatant with the given
    /// effective max health (`base max + toughness`). Scales with Agility using
    /// the diminishing returns curve.
    func controlMeterThreshold(baseMaxHealth: Int) -> Int {
        let agilityResist = 1.0 + Self.diminishingReturnsPercent(for: agility)
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
            Self.diminishingReturnsPercent(for: agility)
        case .burn, .freeze:
            Self.diminishingReturnsPercent(for: intellect)
        case .poison, .holy, .health, .leech:
            Self.diminishingReturnsPercent(for: wisdom)
        default:
            0.0
        }
        return max(0, attackCurve - Self.diminishingReturnsPercent(for: defenderToughness))
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
