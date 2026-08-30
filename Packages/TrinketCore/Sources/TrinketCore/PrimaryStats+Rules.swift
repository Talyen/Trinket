import Foundation

public extension PrimaryStats {
    static let playerChanceCap: Double = 0.75

    static func diminishingReturnsPercent(for statValue: Int) -> Double {
        guard statValue > 0 else { return 0.0 }
        return Double(statValue) / (Double(statValue) + 80.0)
    }

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

    func contestedDodgeChance(againstAttackerAgility attackerAgility: Int) -> Double {
        max(
            0,
            Self.diminishingReturnsPercent(for: agility) - Self.diminishingReturnsPercent(for: attackerAgility)
        )
    }

    static let enemyDodgeFalloffConstant: Double = 9.0

    static let partyIncomingControlResistance: Double = 0.25

    func contestedEnemyDodgeChance(againstAttackerAgility attackerAgility: Int) -> Double {
        let base = contestedDodgeChance(againstAttackerAgility: attackerAgility)
        return max(0, base / (1.0 + Self.enemyDodgeFalloffConstant * base))
    }

    var toughnessMitigationPercent: Double {
        Self.diminishingReturnsPercent(for: toughness)
    }

    func controlMeterThreshold(baseMaxHealth: Int) -> Int {
        let agilityResist = 1.0 + Self.diminishingReturnsPercent(for: agility)
        return max(1, CombatRounding.rounded(Double(baseMaxHealth) * 0.20 * agilityResist))
    }

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
    var enemyDodgeChanceCap: Double {
        switch self {
        case .assassin: 0.10
        case .bruiser: 0.08
        case .mage, .tank, .support: 0.05
        }
    }

    var enemyCriticalChanceCap: Double {
        switch self {
        case .assassin: 0.35
        case .bruiser, .mage: 0.30
        case .tank, .support: 0.20
        }
    }
}
