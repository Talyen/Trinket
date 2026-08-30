import Foundation

public struct CombatPowerSnapshot: Equatable, Sendable {
    public let level: Int
    public let maxHealth: Int
    public let rating: Int

    public init(
        level: Int,
        maxHealth: Int,
        rating: Int,
    ) {
        self.level = level
        self.maxHealth = maxHealth
        self.rating = rating
    }
}

public enum CombatPowerRating {
    public static func evaluate(
        maxHealth: Int,
        primaryStats: PrimaryStats,
        level: Int,
    ) -> CombatPowerSnapshot {
        CombatPowerSnapshot(
            level: level,
            maxHealth: maxHealth,
            rating: maxHealth + primaryStats.total,
        )
    }
}
