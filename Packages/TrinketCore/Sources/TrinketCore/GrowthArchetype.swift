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

    /// Level-1 primary stats for enemies of this archetype. Budget is 50.
    /// Offsets are ±2–3 from an even 10/10/10/10/10 split. Heroes and companions
    /// keep authored identity stats.
    public var identityPrimaryStats: PrimaryStats {
        switch self {
        case .tank:
            PrimaryStats(strength: 11, agility: 8, toughness: 13, intellect: 8, wisdom: 10)
        case .bruiser:
            PrimaryStats(strength: 13, agility: 8, toughness: 11, intellect: 8, wisdom: 10)
        case .assassin:
            PrimaryStats(strength: 9, agility: 13, toughness: 9, intellect: 8, wisdom: 11)
        case .mage:
            PrimaryStats(strength: 8, agility: 9, toughness: 9, intellect: 13, wisdom: 11)
        case .support:
            PrimaryStats(strength: 8, agility: 10, toughness: 9, intellect: 10, wisdom: 13)
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
        return (
            maxHealth: max(1, CombatRounding.scaled(maxHealth, multiplier: healthMultiplier)),
            maxMana: CombatRounding.scaled(maxMana, multiplier: statsMultiplier),
            primaryStats: PrimaryStats(
                strength: CombatRounding.scaled(primaryStats.strength, multiplier: statsMultiplier),
                agility: CombatRounding.scaled(primaryStats.agility, multiplier: statsMultiplier),
                toughness: CombatRounding.scaled(primaryStats.toughness, multiplier: statsMultiplier),
                intellect: CombatRounding.scaled(primaryStats.intellect, multiplier: statsMultiplier),
                wisdom: CombatRounding.scaled(primaryStats.wisdom, multiplier: statsMultiplier)
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
