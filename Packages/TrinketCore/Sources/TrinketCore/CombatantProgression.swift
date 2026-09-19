import Foundation

public struct CombatantProgression: Equatable, Hashable, Codable, Sendable {
    public let level: Int
    public let currentXP: Int
    public let requiredXP: Int

    public static func requiredXP(forLevel level: Int) -> Int {
        guard level > 1 else { return 10 }
        let steps = level - 1
        // Quadratic curve 10 + 5·steps + steps²/2 with saturation instead of
        // trapping; steps is non-negative here so saturation only goes upward.
        let fiveSteps = SaturatedArithmetic.saturatingMul(steps, 5)
        if fiveSteps == Int.max {
            return Int.max
        }
        let square = SaturatedArithmetic.saturatingMul(steps, steps)
        if square == Int.max {
            return Int.max
        }
        let base = SaturatedArithmetic.saturatingAdd(10, fiveSteps)
        if base == Int.max {
            return Int.max
        }
        return SaturatedArithmetic.saturatingAdd(base, square / 2)
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
        // Saturates instead of trapping; preserves the previous
        // overflow-to-Int.max behavior exactly.
        var nextXP = SaturatedArithmetic.saturatingAdd(currentXP, amount)
        var nextRequiredXP = requiredXP

        while nextRequiredXP > 0, nextXP >= nextRequiredXP {
            nextXP -= nextRequiredXP
            guard nextLevel < Int.max else { break }
            nextLevel += 1
            nextRequiredXP = Self.requiredXP(forLevel: nextLevel)
        }

        return Self(
            level: nextLevel,
            currentXP: nextXP,
            requiredXP: nextRequiredXP,
        )
    }

    /// Point budget owned here; unlock legality lives in `TalentModels`.
    public var totalTalentPoints: Int {
        max(level, 0) / 2
    }

    public func availableTalentPoints(unlockedCount: Int) -> Int {
        // Clamp negative counts (impossible from real callers, previously
        // trapping on Int.min) before subtracting so no input can trap.
        max(totalTalentPoints - max(unlockedCount, 0), 0)
    }
}
