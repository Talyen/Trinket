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

    public static let zero = Self()

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
        levelsAbove: Int
    ) -> StatGrowthDelta {
        guard levelsAbove > 0 else { return .zero }
        var growth = playerGrowth(archetype: archetype, levelsAbove: levelsAbove)
        growth.maxMana = 0
        growth.maxHealth = 0
        return growth
    }

    public static func applyPowerMultiplier(
        maxHealth: Int,
        maxMana: Int,
        primaryStats: PrimaryStats,
        healthMultiplier: Double,
        statsMultiplier: Double
    ) -> (maxHealth: Int, maxMana: Int, primaryStats: PrimaryStats) {
        guard healthMultiplier != 1.0 || statsMultiplier != 1.0 else {
            return (maxHealth, maxMana, primaryStats)
        }
        func scaled(_ value: Int, multiplier: Double) -> Int {
            max(0, Int((Double(value) * multiplier).rounded()))
        }
        return (
            maxHealth: max(1, scaled(maxHealth, multiplier: healthMultiplier)),
            maxMana: scaled(maxMana, multiplier: statsMultiplier),
            primaryStats: PrimaryStats(
                strength: scaled(primaryStats.strength, multiplier: statsMultiplier),
                agility: scaled(primaryStats.agility, multiplier: statsMultiplier),
                toughness: scaled(primaryStats.toughness, multiplier: statsMultiplier),
                intellect: scaled(primaryStats.intellect, multiplier: statsMultiplier),
                wisdom: scaled(primaryStats.wisdom, multiplier: statsMultiplier)
            )
        )
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
