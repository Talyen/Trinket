import Foundation

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
