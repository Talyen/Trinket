import Foundation

public enum GrowthArchetype: String, Codable, Hashable, Sendable, CaseIterable {
    case tank
    case assassin
    case mage
    case support
    case bruiser

    public var displayName: String {
        switch self {
        case .tank: "Tank"
        case .assassin: "Assassin"
        case .mage: "Mage"
        case .support: "Support"
        case .bruiser: "Bruiser"
        }
    }
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

struct EnemyGearCompensation: Equatable {
    let healthMultiplier: Double
    let primaryStatMultiplier: Double
    let statDelta: StatGrowthDelta

    static let none = EnemyGearCompensation(
        healthMultiplier: 1.0,
        primaryStatMultiplier: 1.0,
        statDelta: .zero
    )
}

public enum StatGrowth {
    /// Levels above identity (level 1). Level 1 returns zero growth.
    public static func levelsAboveIdentity(_ level: Int) -> Int {
        max(0, level - 1)
    }

    private enum RankedPrimaryStat: CaseIterable {
        case strength, agility, toughness, intellect, wisdom

        func value(in stats: PrimaryStats) -> Int {
            switch self {
            case .strength: stats.strength
            case .agility: stats.agility
            case .toughness: stats.toughness
            case .intellect: stats.intellect
            case .wisdom: stats.wisdom
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
        var growth = playerGrowth(archetype: archetype, levelsAbove: levelsAbove)
        growth.maxMana = 0
        return growth
    }

    private static func bossGrowth(
        levelsAbove: Int,
        identityStats: PrimaryStats
    ) -> StatGrowthDelta {
        let ranked = RankedPrimaryStat.allCases.sorted {
            $0.value(in: identityStats) > $1.value(in: identityStats)
        }

        var delta = StatGrowthDelta(
            maxHealth: Int((Double(levelsAbove) * 1.7).rounded()) + (levelsAbove / 15)
        )
        ranked.first?.apply(levelsAbove, to: &delta)
        if ranked.count > 1 {
            ranked[1].apply(every(levelsAbove, interval: 2, amount: 1), to: &delta)
        }
        return delta
    }

    public static func enemyLateGameBracketBonus(identityStats: PrimaryStats) -> StatGrowthDelta {
        var delta = StatGrowthDelta(toughness: 2)
        if let topStat = RankedPrimaryStat.allCases.max(by: {
            $0.value(in: identityStats) < $1.value(in: identityStats)
        }) {
            topStat.apply(1, to: &delta)
        }
        return delta
    }

    /// Smooth gear-compensation tuned for normal enemies and bosses.
    static func enemyGearCompensation(
        level: Int,
        identityStats: PrimaryStats,
        isBoss: Bool = false
    ) -> EnemyGearCompensation {
        let progress = smoothstep(min(max(Double(level) / 40.0, 0), 1))
        let midT = smoothstep(min(max((Double(level) - 5.0) / 20.0, 0), 1))
        let lateT = smoothstep(min(max((Double(level) - 18.0) / 22.0, 0), 1))
        let earlyT = smoothstep(min(max((14.0 - Double(level)) / 14.0, 0), 1))
        let midPeakT = smoothstep(max(0, 1.0 - abs(Double(level) - 20.0) / 12.0))
        let bracket = enemyLateGameBracketBonus(identityStats: identityStats)

        let healthMultiplier: Double
        let primaryStatMultiplier: Double
        let statScale: Double
        let extraToughness: Int

        if isBoss {
            // Bosses spike threat via stats; keep late HP moderate to avoid 100-tick stalls.
            healthMultiplier = 1.0 + 0.10 + (0.08 * progress) + (0.06 * midT) + (0.02 * lateT)
                + (0.70 * earlyT) + (0.30 * midPeakT)
            primaryStatMultiplier = 1.0 + (0.10 * progress) + (0.16 * midT) + (0.22 * lateT)
                + (0.46 * earlyT) + (0.20 * midPeakT)
            statScale = (0.50 * progress) + (0.32 * midT) + (0.48 * lateT) + (0.62 * earlyT) + (0.34 * midPeakT)
            extraToughness = Int((1.0 + (1.5 * lateT) + (2.5 * earlyT) + (1.5 * midPeakT)).rounded())
        } else {
            // Normal enemies: extra compensation for 2v1 party advantage at matched level.
            healthMultiplier = 1.0 + 0.08 + (0.14 * progress) + (0.64 * midT) + (0.46 * lateT)
                + (0.26 * midPeakT)
            primaryStatMultiplier = 1.0 + (0.06 * progress) + (0.52 * midT) + (0.40 * lateT)
                + (0.20 * midPeakT)
            statScale = (0.58 * progress) + (0.76 * midT) + (0.52 * lateT) + (0.34 * midPeakT)
            extraToughness = Int((1.0 + (1.8 * midT) + (1.2 * lateT) + (1.2 * midPeakT)).rounded())
        }

        let statDelta = StatGrowthDelta(
            strength: scaledByCurve(bracket.strength, statScale),
            agility: scaledByCurve(bracket.agility, statScale),
            toughness: scaledByCurve(bracket.toughness + extraToughness, statScale),
            intellect: scaledByCurve(bracket.intellect, statScale),
            wisdom: scaledByCurve(bracket.wisdom, statScale)
        )
        return EnemyGearCompensation(
            healthMultiplier: healthMultiplier,
            primaryStatMultiplier: primaryStatMultiplier,
            statDelta: statDelta
        )
    }

    /// Applies gear-compensation scaling for enemies that do not carry player equipment.
    public static func applyEnemyGearCompensation(
        maxHealth: Int,
        maxMana: Int,
        primaryStats: PrimaryStats,
        level: Int,
        isBoss: Bool = false
    ) -> (maxHealth: Int, maxMana: Int, primaryStats: PrimaryStats) {
        let compensation = enemyGearCompensation(
            level: level,
            identityStats: primaryStats,
            isBoss: isBoss
        )
        guard compensation != .none else {
            return (maxHealth, maxMana, primaryStats)
        }

        let scaledHealth = max(
            1,
            Int((Double(maxHealth) * compensation.healthMultiplier).rounded())
        )
        let merged = apply(
            maxHealth: scaledHealth,
            maxMana: maxMana,
            primaryStats: primaryStats,
            growth: compensation.statDelta
        )
        return (
            merged.maxHealth,
            merged.maxMana,
            scalePrimaryStatsForEnemyGearCompensation(
                merged.primaryStats,
                multiplier: compensation.primaryStatMultiplier
            )
        )
    }

    private static func scalePrimaryStatsForEnemyGearCompensation(
        _ stats: PrimaryStats,
        multiplier: Double
    ) -> PrimaryStats {
        guard multiplier != 1.0 else { return stats }
        func scaled(_ value: Int) -> Int {
            max(0, Int((Double(value) * multiplier).rounded()))
        }
        return PrimaryStats(
            strength: scaled(stats.strength),
            agility: scaled(stats.agility),
            toughness: scaled(stats.toughness),
            intellect: scaled(stats.intellect),
            wisdom: scaled(stats.wisdom)
        )
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
