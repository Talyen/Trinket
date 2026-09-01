import Foundation

public struct CombatPowerSnapshot: Equatable, Sendable {
    public let level: Int
    public let maxHealth: Int
    public let rawDamagePercent: Double

    public init(
        level: Int,
        maxHealth: Int,
        rawDamagePercent: Double,
    ) {
        self.level = level
        self.maxHealth = maxHealth
        self.rawDamagePercent = rawDamagePercent
    }
}

public enum CombatPowerRating {
    public static func evaluate(
        maxHealth: Int,
        rawDamagePercent: Double,
        level: Int,
    ) -> CombatPowerSnapshot {
        CombatPowerSnapshot(
            level: level,
            maxHealth: maxHealth,
            rawDamagePercent: rawDamagePercent,
        )
    }
}
