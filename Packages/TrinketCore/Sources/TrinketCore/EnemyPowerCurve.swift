import Foundation

public enum EnemyPowerCurve {
    private static let normalHPAnchors: [(level: Int, value: Double)] = [
        (1, 6.40),
        (20, 16.00),
        (40, 58.00),
    ]

    private static let bossHPAnchors: [(level: Int, value: Double)] = [
        (1, 7.50),
        (20, 28.00),
        (40, 85.00),
    ]

    private static let normalDamageAnchors: [(level: Int, value: Double)] = [
        (1, 0.50),
        (20, 1.20),
        (40, 2.50),
    ]

    private static let bossDamageAnchors: [(level: Int, value: Double)] = [
        (1, 0.60),
        (20, 0.95),
        (40, 2.30),
    ]

    public static func health(level: Int, isBoss: Bool) -> Double {
        interpolate(max(1, level), anchors: isBoss ? bossHPAnchors : normalHPAnchors)
    }

    public static func rawDamagePercent(level: Int, isBoss: Bool) -> Double {
        interpolate(max(1, level), anchors: isBoss ? bossDamageAnchors : normalDamageAnchors)
    }

    private static func interpolate(_ level: Int, anchors: [(level: Int, value: Double)]) -> Double {
        guard let first = anchors.first else { return 1 }
        if level <= first.level {
            return first.value
        }
        guard let last = anchors.last else { return first.value }
        if level >= last.level {
            return last.value
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

    package static func progressionSmoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}
