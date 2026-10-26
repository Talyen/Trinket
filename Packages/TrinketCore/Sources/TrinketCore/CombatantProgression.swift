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
        // Two nonnegative Int balances fit in UInt. Keep their full sum until
        // level costs are paid so saturation cannot discard earned XP.
        var nextXP = UInt(max(0, currentXP)) + UInt(amount)
        var nextRequiredXP = requiredXP

        while nextRequiredXP > 0, nextXP >= UInt(nextRequiredXP) {
            guard nextLevel < Int.max else { break }
            nextXP -= UInt(nextRequiredXP)
            nextLevel += 1
            nextRequiredXP = Self.requiredXP(forLevel: nextLevel)
        }

        return Self(
            level: nextLevel,
            currentXP: Int(min(nextXP, UInt(Int.max))),
            requiredXP: nextRequiredXP,
        )
    }

    /// Earned XP between two forward progressions, independent of the lifetime
    /// display total's saturation. Backwards transitions have no earned award.
    public func experienceGained(since previous: Self) -> Int? {
        guard level >= previous.level, level > 0, previous.level > 0,
              currentXP >= 0, previous.currentXP >= 0 else { return nil }
        if level == previous.level {
            return currentXP >= previous.currentXP ? currentXP - previous.currentXP : nil
        }
        guard previous.requiredXP > 0, previous.currentXP < previous.requiredXP else { return nil }
        let firstLevel = previous.requiredXP - previous.currentXP
        let intermediate = Self.experienceCost(startingAt: previous.level + 1, count: level - previous.level - 1)
        return SaturatedArithmetic.saturatingAdd(
            firstLevel, SaturatedArithmetic.saturatingAdd(intermediate, currentXP),
        )
    }

    /// Sum a contiguous part of the canonical curve without subtracting large
    /// lifetime totals or walking an untrusted saved level gap. All terms are
    /// nonnegative, so saturating each addition preserves the capped result.
    private static func experienceCost(startingAt level: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let steps = level - 1
        let triangular = count.isMultiple(of: 2)
            ? SaturatedArithmetic.saturatingMul(count / 2, count - 1)
            : SaturatedArithmetic.saturatingMul(count, (count - 1) / 2)
        let linear = SaturatedArithmetic.saturatingMul(
            SaturatedArithmetic.saturatingAdd(steps, 5), triangular,
        )
        let paired = count / 2
        // Sum floor(j²/2) for j in 0..<count: p(p-1)(4p+1)/3,
        // plus 2p² for an unpaired final index. Divide before multiplying.
        let squares: Int
        if paired == 0 {
            squares = 0
        } else if paired % 3 == 2 {
            squares = SaturatedArithmetic.saturatingMul(
                SaturatedArithmetic.saturatingMul(paired, paired - 1),
                SaturatedArithmetic.saturatingAdd(SaturatedArithmetic.saturatingMul(paired / 3, 4), 3),
            )
        } else {
            let first = paired.isMultiple(of: 3) ? paired / 3 : paired
            let second = paired.isMultiple(of: 3) ? paired - 1 : (paired - 1) / 3
            squares = SaturatedArithmetic.saturatingMul(
                SaturatedArithmetic.saturatingMul(first, second),
                SaturatedArithmetic.saturatingAdd(SaturatedArithmetic.saturatingMul(paired, 4), 1),
            )
        }
        let unpaired = count.isMultiple(of: 2) ? 0
            : SaturatedArithmetic.saturatingMul(SaturatedArithmetic.saturatingMul(paired, paired), 2)
        let parity = steps.isMultiple(of: 2) ? 0 : paired
        return SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingMul(count, requiredXP(forLevel: level)),
            SaturatedArithmetic.saturatingAdd(linear, SaturatedArithmetic.saturatingAdd(
                squares, SaturatedArithmetic.saturatingAdd(unpaired, parity),
            )),
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
