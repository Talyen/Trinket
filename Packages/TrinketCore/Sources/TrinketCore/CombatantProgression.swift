import Foundation

public struct CombatantProgression: Equatable, Hashable, Codable, Sendable {
    public let level: Int
    public let currentXP: Int
    public let requiredXP: Int

    public static func requiredXP(forLevel level: Int) -> Int {
        let steps = max(level - 1, 0)
        return 100 + (50 * steps) + (5 * steps * steps)
    }

    public static let initial = CombatantProgression(
        level: 1,
        currentXP: 0,
        requiredXP: requiredXP(forLevel: 1)
    )

    public init(level: Int, currentXP: Int, requiredXP: Int) {
        self.level = level
        self.currentXP = currentXP
        self.requiredXP = requiredXP
    }

    public var progressFraction: Double {
        guard requiredXP > 0 else { return 0 }
        return min(max(Double(currentXP) / Double(requiredXP), 0), 1)
    }

    public func unlocks(_ tier: AbilityTier) -> Bool {
        level >= tier.unlockLevel
    }

    public func addingExperience(_ amount: Int) -> CombatantProgression {
        guard amount > 0 else { return self }

        var nextLevel = level
        var nextXP = currentXP + amount
        var nextRequiredXP = requiredXP

        while nextRequiredXP > 0, nextXP >= nextRequiredXP {
            nextXP -= nextRequiredXP
            nextLevel += 1
            nextRequiredXP = Self.requiredXP(forLevel: nextLevel)
        }

        return CombatantProgression(
            level: nextLevel,
            currentXP: nextXP,
            requiredXP: nextRequiredXP
        )
    }
}
