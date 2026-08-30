import Foundation

enum ProgressionBracket: Equatable {
    case early
    case mid
    case late

    static func forLevel(_ level: Int) -> Self {
        if level < 20 {
            return .early
        }
        if level < 40 {
            return .mid
        }
        return .late
    }

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
    public static let maxGrantLevelsEquivalent = 3

    public static func levelDeltaMultiplier(playerLevel: Int, enemyLevel: Int) -> Double {
        let gap = playerLevel - enemyLevel
        guard gap < underlevelCutoff else { return 0 }
        guard gap > 0 else { return 1 }

        let normalized = 1.0 - (Double(gap) / Double(underlevelCutoff))
        return EnemyPowerCurve.progressionSmoothstep(normalized)
    }

    public static func baseBattleAward(forPlayerLevel level: Int) -> Int {
        let required = CombatantProgression.requiredXP(forLevel: level)
        let battles = ProgressionBracket.forLevel(level).targetBattlesPerLevel
        return max(1, CombatRounding.rounded(Double(required) / battles))
    }

    public static func battleAward(playerLevel: Int, enemyLevel: Int) -> Int {
        adjustedAward(
            baseExperience: baseBattleAward(forPlayerLevel: playerLevel),
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
        )
    }

    public static func battleAwardWithCatchUp(
        playerLevel: Int,
        enemyLevel: Int,
        highestLevel: Int,
    ) -> Int {
        let award = battleAward(playerLevel: playerLevel, enemyLevel: enemyLevel)
        guard award > 0 else { return 0 }
        let catchUp = catchUpMultiplier(for: playerLevel, highestLevel: highestLevel)
        return max(1, CombatRounding.scaled(award, multiplier: catchUp))
    }

    public static func equalBattleAward(playerLevel: Int, highestLevel: Int) -> Int {
        battleAwardWithCatchUp(
            playerLevel: playerLevel,
            enemyLevel: playerLevel,
            highestLevel: highestLevel,
        )
    }

    public static func cappedAward(_ amount: Int, for progression: CombatantProgression) -> Int {
        cappedAward(amount, requiredXP: progression.requiredXP)
    }

    public static func cappedAward(_ amount: Int, requiredXP: Int) -> Int {
        guard amount > 0 else { return 0 }
        let ceiling = max(0, requiredXP) * maxGrantLevelsEquivalent
        return min(amount, ceiling)
    }

    public static func adjustedAward(
        baseExperience: Int,
        playerLevel: Int,
        enemyLevel: Int,
    ) -> Int {
        guard baseExperience > 0 else { return 0 }
        let multiplier = levelDeltaMultiplier(playerLevel: playerLevel, enemyLevel: enemyLevel)
        return CombatRounding.scaled(baseExperience, multiplier: multiplier)
    }

    public static func catchUpMultiplier(
        for combatantLevel: Int,
        highestLevel: Int,
        maxMultiplier: Double = 2.5,
    ) -> Double {
        let gap = max(0, highestLevel - combatantLevel)
        guard gap > 0 else { return 1.0 }
        let decayConstant = 2.0
        return 1.0 + (maxMultiplier - 1.0) * (1.0 - exp(-Double(gap) / decayConstant))
    }
}
