import Foundation

public enum GrowthArchetype: String, Codable, Hashable, Sendable, CaseIterable {
    case tank
    case assassin
    case mage
    case support
    case bruiser
}

public struct StatGrowthDelta: Equatable, Hashable, Sendable {
    public var strength: Int
    public var agility: Int
    public var toughness: Int
    public var intellect: Int
    public var wisdom: Int
    public var maxHealth: Int
    public var maxMana: Int

    public static let zero = StatGrowthDelta()

    public init(
        strength: Int = 0,
        agility: Int = 0,
        toughness: Int = 0,
        intellect: Int = 0,
        wisdom: Int = 0,
        maxHealth: Int = 0,
        maxMana: Int = 0
    ) {
        self.strength = strength
        self.agility = agility
        self.toughness = toughness
        self.intellect = intellect
        self.wisdom = wisdom
        self.maxHealth = maxHealth
        self.maxMana = maxMana
    }
}

public enum StatGrowth {
    /// Levels above identity (level 1). Level 1 returns zero growth.
    public static func levelsAboveIdentity(_ level: Int) -> Int {
        max(0, level - 1)
    }

    private static func every(_ levelsAbove: Int, interval: Int, amount: Int) -> Int {
        guard interval > 0, amount != 0, levelsAbove > 0 else { return 0 }
        return (levelsAbove / interval) * amount
    }

    public static func playerGrowth(
        archetype: GrowthArchetype,
        levelsAbove: Int
    ) -> StatGrowthDelta {
        guard levelsAbove > 0 else { return .zero }

        var delta = StatGrowthDelta(maxHealth: levelsAbove)

        switch archetype {
        case .tank:
            delta.strength = every(levelsAbove, interval: 2, amount: 1)
            delta.toughness = levelsAbove
            delta.wisdom = every(levelsAbove, interval: 4, amount: 1)
        case .assassin:
            delta.agility = levelsAbove
            delta.toughness = every(levelsAbove, interval: 4, amount: 1)
            delta.wisdom = every(levelsAbove, interval: 2, amount: 1)
        case .mage:
            delta.toughness = every(levelsAbove, interval: 4, amount: 1)
            delta.intellect = levelsAbove
            delta.wisdom = every(levelsAbove, interval: 4, amount: 1)
            delta.maxMana = every(levelsAbove, interval: 2, amount: 1)
        case .support:
            delta.agility = every(levelsAbove, interval: 4, amount: 1)
            delta.toughness = every(levelsAbove, interval: 2, amount: 1)
            delta.intellect = every(levelsAbove, interval: 2, amount: 1)
            delta.wisdom = levelsAbove
            delta.maxMana = every(levelsAbove, interval: 2, amount: 1)
        case .bruiser:
            delta.strength = levelsAbove
            delta.agility = every(levelsAbove, interval: 4, amount: 1)
            delta.toughness = every(levelsAbove, interval: 2, amount: 1)
        }

        return delta
    }

    public static func enemyGrowth(
        archetype: GrowthArchetype,
        isBoss: Bool,
        levelsAbove: Int,
        identityStats: PrimaryStats
    ) -> StatGrowthDelta {
        guard levelsAbove > 0 else { return .zero }

        if isBoss {
            return bossGrowth(levelsAbove: levelsAbove, identityStats: identityStats)
        }

        var delta = StatGrowthDelta(maxHealth: levelsAbove)
        let archetypeGrowth = playerGrowth(archetype: archetype, levelsAbove: levelsAbove)
        delta.strength = archetypeGrowth.strength
        delta.agility = archetypeGrowth.agility
        delta.toughness = archetypeGrowth.toughness
        delta.intellect = archetypeGrowth.intellect
        delta.wisdom = archetypeGrowth.wisdom
        delta.maxMana = archetypeGrowth.maxMana
        return delta
    }

    private static func bossGrowth(
        levelsAbove: Int,
        identityStats: PrimaryStats
    ) -> StatGrowthDelta {
        enum StatKey: CaseIterable {
            case strength, agility, toughness, intellect, wisdom

            func value(in stats: PrimaryStats) -> Int {
                switch self {
                case .strength: return stats.strength
                case .agility: return stats.agility
                case .toughness: return stats.toughness
                case .intellect: return stats.intellect
                case .wisdom: return stats.wisdom
                }
            }

            func apply(_ amount: Int, to delta: inout StatGrowthDelta) {
                switch self {
                case .strength: delta.strength += amount
                case .agility: delta.agility += amount
                case .toughness: delta.toughness += amount
                case .intellect: delta.intellect += amount
                case .wisdom: delta.wisdom += amount
                }
            }
        }

        let ranked = StatKey.allCases.sorted {
            $0.value(in: identityStats) > $1.value(in: identityStats)
        }

        var delta = StatGrowthDelta(
            maxHealth: Int((Double(levelsAbove) * 2.5).rounded()) + (levelsAbove / 8)
        )
        ranked.first?.apply(levelsAbove, to: &delta)
        if ranked.count > 1 {
            ranked[1].apply(every(levelsAbove, interval: 2, amount: 1), to: &delta)
        }
        return delta
    }

    public static func enemyLateGameBracketBonus(identityStats: PrimaryStats) -> StatGrowthDelta {
        enum StatKey: CaseIterable {
            case strength, agility, toughness, intellect, wisdom

            func value(in stats: PrimaryStats) -> Int {
                switch self {
                case .strength: return stats.strength
                case .agility: return stats.agility
                case .toughness: return stats.toughness
                case .intellect: return stats.intellect
                case .wisdom: return stats.wisdom
                }
            }

            func apply(_ amount: Int, to delta: inout StatGrowthDelta) {
                switch self {
                case .strength: delta.strength += amount
                case .agility: delta.agility += amount
                case .toughness: delta.toughness += amount
                case .intellect: delta.intellect += amount
                case .wisdom: delta.wisdom += amount
                }
            }
        }

        var delta = StatGrowthDelta(toughness: 2)
        if let topStat = StatKey.allCases.max(by: { $0.value(in: identityStats) < $1.value(in: identityStats) }) {
            topStat.apply(1, to: &delta)
        }
        return delta
    }

    /// Smooth gear-compensation ramp from level 1 through 40+ (replaces mid/late bracket cliffs).
    /// Health reaches +25% at level 40; primary stats scale the late-game bracket bonus by the same curve.
    public static func enemyGearCompensation(
        level: Int,
        identityStats: PrimaryStats
    ) -> (healthMultiplier: Double, statDelta: StatGrowthDelta) {
        guard level > 1 else { return (1.0, .zero) }

        let normalized = min(max(Double(level - 1) / 39.0, 0), 1)
        let t = smoothstep(normalized)
        let healthMultiplier = 1.0 + (0.25 * t)
        let bracket = enemyLateGameBracketBonus(identityStats: identityStats)
        let statDelta = StatGrowthDelta(
            strength: scaledByCurve(bracket.strength, t),
            agility: scaledByCurve(bracket.agility, t),
            toughness: scaledByCurve(bracket.toughness + 1, t),
            intellect: scaledByCurve(bracket.intellect, t),
            wisdom: scaledByCurve(bracket.wisdom, t)
        )
        return (healthMultiplier, statDelta)
    }

    private static func scaledByCurve(_ amount: Int, _ t: Double) -> Int {
        Int((Double(amount) * t).rounded())
    }

    private static func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }

    public static func apply(
        maxHealth: Int,
        maxMana: Int,
        primaryStats: PrimaryStats,
        growth: StatGrowthDelta
    ) -> (maxHealth: Int, maxMana: Int, primaryStats: PrimaryStats) {
        (
            maxHealth: maxHealth + growth.maxHealth,
            maxMana: maxMana + growth.maxMana,
            primaryStats: PrimaryStats(
                strength: primaryStats.strength + growth.strength,
                agility: primaryStats.agility + growth.agility,
                toughness: primaryStats.toughness + growth.toughness,
                intellect: primaryStats.intellect + growth.intellect,
                wisdom: primaryStats.wisdom + growth.wisdom
            )
        )
    }
}
