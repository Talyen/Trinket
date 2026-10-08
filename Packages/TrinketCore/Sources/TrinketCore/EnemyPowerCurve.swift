import Foundation

public enum EnemyPowerCurve {
    /// Bracket boundaries; the single source of truth read directly by
    /// `ExperienceScaling.baseBattleAward`.
    static let midLevel = 20
    static let lateLevel = 40

    public static func health(level: Int, isBoss: Bool) -> Double {
        interpolate(
            max(1, level), values: isBoss ? (7.50, 28.00, 85.00) : (6.40, 16.00, 58.00),
            logarithmicTail: true,
        )
    }

    public static func rawDamagePercent(level: Int, isBoss: Bool) -> Double {
        interpolate(
            max(1, level), values: isBoss ? (0.20, 0.95, 2.30) : (0.50, 1.20, 2.50),
            logarithmicTail: false,
        )
    }

    private static func interpolate(
        _ level: Int,
        values: (early: Double, mid: Double, late: Double),
        logarithmicTail: Bool,
    ) -> Double {
        if level > lateLevel {
            let progress = Double(level - lateLevel) / Double(lateLevel - midLevel)
            let growth = logarithmicTail ? log1p(progress) : progress
            return values.late + (values.late - values.mid) * growth
        }
        let low: (level: Int, value: Double)
        let high: (level: Int, value: Double)
        if level <= midLevel {
            low = (1, values.early)
            high = (midLevel, values.mid)
        } else {
            low = (midLevel, values.mid)
            high = (lateLevel, values.late)
        }
        let normalized = Double(level - low.level) / Double(high.level - low.level)
        let eased = progressionSmoothstep(normalized)
        return low.value + (high.value - low.value) * eased
    }

    /// Shared easing for curve interpolation and XP falloff within Core.
    static func progressionSmoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}
