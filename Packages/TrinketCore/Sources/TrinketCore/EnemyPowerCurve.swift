import Foundation

public enum EnemyPowerCurve {
    public static let bossHealthMultiplier = 1.75

    private static let normalStatAnchors: [(level: Int, power: Double)] = [
        (1, 4.20),
        (20, 5.59),
        (40, 9.30),
    ]

    private static let bossStatAnchors: [(level: Int, power: Double)] = [
        (1, 5.20),
        (20, 10.77),
        (40, 24.50),
    ]

    public static func stats(level: Int, isBoss: Bool) -> Double {
        interpolate(max(1, level), anchors: isBoss ? bossStatAnchors : normalStatAnchors)
    }

    public static func health(level: Int, isBoss: Bool) -> Double {
        let base = interpolate(max(1, level), anchors: normalStatAnchors)
        return isBoss ? base * bossHealthMultiplier : base
    }

    private static func interpolate(_ level: Int, anchors: [(level: Int, power: Double)]) -> Double {
        guard let first = anchors.first else { return 1 }
        if level <= first.level {
            return first.power
        }
        guard let last = anchors.last else { return first.power }
        if level >= last.level {
            return last.power
        }

        for index in 0 ..< (anchors.count - 1) {
            let low = anchors[index]
            let high = anchors[index + 1]
            guard level >= low.level, level <= high.level else { continue }
            let span = high.level - low.level
            guard span > 0 else { return high.power }
            let normalized = Double(level - low.level) / Double(span)
            let eased = progressionSmoothstep(normalized)
            return low.power + (high.power - low.power) * eased
        }

        return last.power
    }

    package static func progressionSmoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}
