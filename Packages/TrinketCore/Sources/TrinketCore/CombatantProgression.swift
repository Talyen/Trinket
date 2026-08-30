import Foundation

public struct CombatantProgression: Equatable, Hashable, Codable, Sendable {
    public let level: Int
    public let currentXP: Int
    public let requiredXP: Int

    public static func requiredXP(forLevel level: Int) -> Int {
        let steps = max(level - 1, 0)
        return 10 + (5 * steps) + ((steps * steps) / 2)
    }

    public static let initial = Self(
        level: 1,
        currentXP: 0,
        requiredXP: requiredXP(forLevel: 1),
    )

    public static func at(level: Int) -> Self {
        let clamped = max(level, 1)
        return Self(
            level: clamped,
            currentXP: 0,
            requiredXP: requiredXP(forLevel: clamped),
        )
    }

    public init(level: Int, currentXP: Int, requiredXP: Int) {
        self.level = level
        self.currentXP = currentXP
        self.requiredXP = requiredXP
    }

    public var progressFraction: Double {
        guard requiredXP > 0 else { return 0 }
        return min(max(Double(currentXP) / Double(requiredXP), 0), 1)
    }

    public func addingExperience(_ amount: Int) -> Self {
        guard amount > 0 else { return self }

        var nextLevel = level
        var nextXP = currentXP + amount
        var nextRequiredXP = requiredXP

        while nextRequiredXP > 0, nextXP >= nextRequiredXP {
            nextXP -= nextRequiredXP
            nextLevel += 1
            nextRequiredXP = Self.requiredXP(forLevel: nextLevel)
        }

        return Self(
            level: nextLevel,
            currentXP: nextXP,
            requiredXP: nextRequiredXP,
        )
    }

    public var totalTalentPoints: Int {
        max(level, 0) / 2
    }

    public func availableTalentPoints(unlockedCount: Int) -> Int {
        max(totalTalentPoints - unlockedCount, 0)
    }
}
