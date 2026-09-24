import Foundation

public enum EnemyPowerCurve {
    /// Bracket boundaries; the single source of truth read directly by
    /// `ProgressionBracket` in ExperienceScaling.swift.
    public static let midLevel = 20
    public static let lateLevel = 40

    private static let normalHPAnchors: [(level: Int, value: Double)] = [
        (1, 6.40),
        (midLevel, 16.00),
        (lateLevel, 58.00),
    ]

    private static let bossHPAnchors: [(level: Int, value: Double)] = [
        (1, 7.50),
        (midLevel, 28.00),
        (lateLevel, 85.00),
    ]

    private static let normalDamageAnchors: [(level: Int, value: Double)] = [
        (1, 0.50),
        (midLevel, 1.20),
        (lateLevel, 2.50),
    ]

    private static let bossDamageAnchors: [(level: Int, value: Double)] = [
        (1, 0.20),
        (midLevel, 0.95),
        (lateLevel, 2.30),
    ]
    // NOTE: boss damage sits below normal damage at the mid/late anchors
    // (0.95 < 1.20, 2.30 < 2.50). Pinned by tests as current tuning,
    // pending battle-owner review on whether that ordering is intentional.

    public static func health(level: Int, isBoss: Bool) -> Double {
        interpolate(max(1, level), anchors: isBoss ? bossHPAnchors : normalHPAnchors, logarithmicTail: true)
    }

    public static func rawDamagePercent(level: Int, isBoss: Bool) -> Double {
        interpolate(max(1, level), anchors: isBoss ? bossDamageAnchors : normalDamageAnchors, logarithmicTail: false)
    }

    private static func interpolate(
        _ level: Int,
        anchors: [(level: Int, value: Double)],
        logarithmicTail: Bool,
    ) -> Double {
        guard let first = anchors.first else { return 1 }
        if level <= first.level {
            return first.value
        }
        guard let last = anchors.last else { return first.value }
        if level > last.level {
            guard let previous = anchors.dropLast().last else { return last.value }
            let span = last.level - previous.level
            guard span > 0 else { return last.value }
            let progress = Double(level - last.level) / Double(span)
            let growth = logarithmicTail ? log1p(progress) : progress
            return last.value + (last.value - previous.value) * growth
        }

        for index in 0 ..< (anchors.count - 1) {
            let low = anchors[index]
            let high = anchors[index + 1]
            guard level >= low.level, level <= high.level else { continue }
            let span = high.level - low.level
            guard span > 0 else { return high.value }
            let normalized = Double(level - low.level) / Double(span)
            let eased = progressionSmoothstep(normalized)
            return low.value + (high.value - low.value) * eased
        }

        return last.value
    }

    /// Shared easing for curve interpolation and XP falloff. Public so the
    /// cross-file caller (`ExperienceScaling`) does not depend on an
    /// undocumented internal; behavior unchanged.
    public static func progressionSmoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}
