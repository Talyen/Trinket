import Foundation

public struct CombatantProgression: Equatable, Hashable, Codable, Sendable {
    public let level: Int
    public let currentXP: Int
    public let requiredXP: Int

    public static func requiredXP(forLevel level: Int) -> Int {
        guard level > 1 else { return 10 }
        let steps = level - 1
        let (fiveSteps, overflow1) = steps.multipliedReportingOverflow(by: 5)
        guard !overflow1 else { return Int.max }
        let (square, overflow2) = steps.multipliedReportingOverflow(by: steps)
        guard !overflow2 else { return Int.max }
        let (base, overflow3) = 10.addingReportingOverflow(fiveSteps)
        guard !overflow3 else { return Int.max }
        let (total, overflow4) = base.addingReportingOverflow(square / 2)
        return overflow4 ? Int.max : total
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
        let (addedXP, overflow) = currentXP.addingReportingOverflow(amount)
        var nextXP = overflow ? Int.max : addedXP
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

    public var totalTalentPoints: Int {
        max(level, 0) / 2
    }

    public func availableTalentPoints(unlockedCount: Int) -> Int {
        max(totalTalentPoints - unlockedCount, 0)
    }
}
