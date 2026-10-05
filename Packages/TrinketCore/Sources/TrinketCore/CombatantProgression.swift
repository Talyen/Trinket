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
        // Divide before multiplying: the square can overflow while half of it still fits.
        let halfSquare = SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingMul(steps / 2, steps),
            steps.isMultiple(of: 2) ? 0 : steps / 2,
        )
        let base = SaturatedArithmetic.saturatingAdd(10, fiveSteps)
        return SaturatedArithmetic.saturatingAdd(base, halfSquare)
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
            guard nextLevel < Int.max else { break }
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

    /// Point budget owned here; unlock legality lives in `TalentModels`.
    public var totalTalentPoints: Int {
        max(level, 0) / 2
    }

    public func availableTalentPoints(unlockedCount: Int) -> Int {
        // Clamp negative counts (impossible from real callers, previously
        // trapping on Int.min) before subtracting so no input can trap.
        max(totalTalentPoints - max(unlockedCount, 0), 0)
    }

    /// Total cumulative experience earned across all prior levels plus currentXP.
    public var totalEarnedExperience: Int {
        guard level > 1 else { return max(0, currentXP) }
        let pairs = (level - 1) / 2
        // Summing pairs of prior levels preserves the curve's integer rounding:
        // requiredXP(1)...requiredXP(2p) = p·(4p²+27p+44)/3.
        let factor = SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingMul(
                SaturatedArithmetic.saturatingAdd(SaturatedArithmetic.saturatingMul(pairs, 4), 27), pairs,
            ), 44,
        )
        guard factor < Int.max else { return Int.max }
        let pairedXP = pairs.isMultiple(of: 3)
            ? SaturatedArithmetic.saturatingMul(pairs / 3, factor)
            : SaturatedArithmetic.saturatingMul(pairs, factor / 3)
        let unpairedXP = level.isMultiple(of: 2) ? Self.requiredXP(forLevel: level - 1) : 0
        return SaturatedArithmetic.saturatingAdd(
            max(0, currentXP), SaturatedArithmetic.saturatingAdd(pairedXP, unpairedXP),
        )
    }
}
