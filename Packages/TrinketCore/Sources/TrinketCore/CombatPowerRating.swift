import Foundation

public struct CombatPowerSnapshot: Equatable, Sendable {
    public let level: Int
    public let powerMultiplier: Double
    public let maxHealth: Int
    public let primaryStatTotal: Int
    public let rating: Int

    public init(
        level: Int,
        powerMultiplier: Double,
        maxHealth: Int,
        primaryStatTotal: Int,
        rating: Int
    ) {
        self.level = level
        self.powerMultiplier = powerMultiplier
        self.maxHealth = maxHealth
        self.primaryStatTotal = primaryStatTotal
        self.rating = rating
    }
}

public enum CombatPowerRating {
    /// Summarizes scaled combat power from final combatant stats and the level power multiplier.
    public static func evaluate(
        maxHealth: Int,
        primaryStats: PrimaryStats,
        level: Int,
        powerMultiplier: Double
    ) -> CombatPowerSnapshot {
        let statTotal = primaryStats.strength
            + primaryStats.agility
            + primaryStats.toughness
            + primaryStats.intellect
            + primaryStats.wisdom
        let rating = maxHealth + statTotal
        return CombatPowerSnapshot(
            level: level,
            powerMultiplier: powerMultiplier,
            maxHealth: maxHealth,
            primaryStatTotal: statTotal,
            rating: rating
        )
    }
}
