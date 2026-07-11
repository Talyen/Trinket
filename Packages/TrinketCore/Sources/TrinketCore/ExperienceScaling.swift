import Foundation

enum ProgressionBracket: Equatable {
    case early
    case mid
    case late

    static func forLevel(_ level: Int) -> ProgressionBracket {
        if level < 20 {
            return .early
        }
        if level < 40 {
            return .mid
        }
        return .late
    }

    /// Target equal-level battles to advance one level.
    var targetBattlesPerLevel: Double {
        switch self {
        case .early: 1.5
        case .mid: 2.5
        case .late: 3.5
        }
    }
}

public enum ExperienceScaling {
    public static let underlevelCutoff = 10

    /// Returns a multiplier in `0...1` for how much of the base experience award applies.
    /// Enemies 10+ levels below the player grant no experience; equal or higher-level enemies grant full experience.
    public static func levelDeltaMultiplier(playerLevel: Int, enemyLevel: Int) -> Double {
        let gap = playerLevel - enemyLevel
        guard gap < underlevelCutoff else { return 0 }
        guard gap > 0 else { return 1 }

        let normalized = 1.0 - (Double(gap) / Double(underlevelCutoff))
        return smoothstep(normalized)
    }

    public static func baseBattleAward(forPlayerLevel level: Int) -> Int {
        let required = CombatantProgression.requiredXP(forLevel: level)
        let battles = ProgressionBracket.forLevel(level).targetBattlesPerLevel
        return max(1, Int((Double(required) / battles).rounded()))
    }

    public static func battleAward(playerLevel: Int, enemyLevel: Int) -> Int {
        adjustedAward(
            baseExperience: baseBattleAward(forPlayerLevel: playerLevel),
            playerLevel: playerLevel,
            enemyLevel: enemyLevel
        )
    }

    /// Battle XP after level-delta scaling and catch-up multiplier; zero awards stay zero.
    public static func battleAwardWithCatchUp(
        playerLevel: Int,
        enemyLevel: Int,
        highestLevel: Int
    ) -> Int {
        let award = battleAward(playerLevel: playerLevel, enemyLevel: enemyLevel)
        guard award > 0 else { return 0 }
        let catchUp = catchUpMultiplier(for: playerLevel, highestLevel: highestLevel)
        return max(1, Int((Double(award) * catchUp).rounded()))
    }

    public static func adjustedAward(
        baseExperience: Int,
        playerLevel: Int,
        enemyLevel: Int
    ) -> Int {
        guard baseExperience > 0 else { return 0 }
        let multiplier = levelDeltaMultiplier(playerLevel: playerLevel, enemyLevel: enemyLevel)
        return max(0, Int((Double(baseExperience) * multiplier).rounded()))
    }

    /// Catch-up XP multiplier. Returns 1.0 when the combatant is at or above
    /// `highestLevel`, smoothly approaching `maxMultiplier` as the level gap grows.
    /// - Parameters:
    ///   - combatantLevel: The level of the combatant receiving XP.
    ///   - highestLevel: The highest level among same-role combatants.
    ///   - maxMultiplier: The maximum multiplier to approach (default 2.5).
    public static func catchUpMultiplier(
        for combatantLevel: Int,
        highestLevel: Int,
        maxMultiplier: Double = 2.5
    ) -> Double {
        let gap = max(0, highestLevel - combatantLevel)
        guard gap > 0 else { return 1.0 }
        let decayConstant = 2.0
        return 1.0 + (maxMultiplier - 1.0) * (1.0 - exp(-Double(gap) / decayConstant))
    }

    private static func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}
