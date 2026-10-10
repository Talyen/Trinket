import Foundation

public enum EnemyPowerCurve {
    public enum Profile: CaseIterable, Hashable, Sendable {
        case standard
        case spire
        case recovery
    }

    /// Bracket boundaries; the single source of truth read directly by
    /// `ExperienceScaling.baseBattleAward`.
    static let midLevel = 20
    static let lateLevel = 40

    public static func health(level: Int, isBoss: Bool, profile: Profile = .standard) -> Double {
        let values = switch (profile, isBoss) {
        case (.standard, false): (6.40, 16.00, 44.00)
        case (.standard, true): (15.00, 28.00, 75.00)
        case (.spire, false): (6.40, 16.00, 35.20)
        case (.spire, true): (10.00, 28.00, 60.00)
        case (.recovery, false): (6.40, 16.00, 44.00)
        case (.recovery, true): (10.00, 28.00, 75.00)
        }
        return interpolate(max(1, level), values: values, logarithmicTail: true)
    }

    public static func rawDamagePercent(level: Int, isBoss: Bool, profile: Profile = .standard) -> Double {
        let values: (Double, Double, Double) = if profile == .standard {
            isBoss ? (0.25, 2.20, 6.50) : (0.50, 4.30, 15.00)
        } else {
            isBoss ? (0.35, 1.10, 3.25) : (0.50, 1.60, 3.25)
        }
        // The level-40 gear jump is not the slope of uncapped post-kit growth.
        let tailStep = profile == .standard ? (isBoss ? 1.35 : 1.30) : nil
        return interpolate(max(1, level), values: values, logarithmicTail: false, tailStep: tailStep)
    }

    private static func interpolate(
        _ level: Int,
        values: (early: Double, mid: Double, late: Double),
        logarithmicTail: Bool,
        tailStep: Double? = nil,
    ) -> Double {
        if level > lateLevel {
            let progress = Double(level - lateLevel) / Double(lateLevel - midLevel)
            let growth = logarithmicTail ? log1p(progress) : progress
            return values.late + (tailStep ?? (values.late - values.mid)) * growth
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
