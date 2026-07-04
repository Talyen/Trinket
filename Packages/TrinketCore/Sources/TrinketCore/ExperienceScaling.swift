import Foundation

public enum ProgressionBracket: Equatable, Sendable {
    case early
    case mid
    case late

    public static func forLevel(_ level: Int) -> ProgressionBracket {
        if level < 20 { return .early }
        if level < 40 { return .mid }
        return .late
    }

    /// Target equal-level battles to advance one level.
    public var targetBattlesPerLevel: Double {
        switch self {
        case .early: return 1.5
        case .mid: return 2.5
        case .late: return 3.5
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

    public static func adjustedAward(
        baseExperience: Int,
        playerLevel: Int,
        enemyLevel: Int
    ) -> Int {
        guard baseExperience > 0 else { return 0 }
        let multiplier = levelDeltaMultiplier(playerLevel: playerLevel, enemyLevel: enemyLevel)
        return max(0, Int((Double(baseExperience) * multiplier).rounded()))
    }

    private static func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}
