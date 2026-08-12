import Foundation

/// Level-based power multiplier for enemies. Replaces gear-compensation step bands.
public enum EnemyPowerCurve {
    private static let normalStatAnchors: [(level: Int, power: Double)] = [
        (1, 2.10),
        (20, 2.65),
        (40, 3.10),
    ]

    private static let bossStatAnchors: [(level: Int, power: Double)] = [
        (1, 3.22),
        (20, 5.10),
        (40, 6.30),
    ]

    /// Stat threat multiplier after archetype growth.
    public static func power(level: Int, isBoss: Bool) -> Double {
        interpolate(max(1, level), anchors: isBoss ? bossStatAnchors : normalStatAnchors)
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
}

/// Hermite smoothstep on `0...1` (clamped).
func progressionSmoothstep(_ value: Double) -> Double {
    let clamped = min(max(value, 0), 1)
    return clamped * clamped * (3 - (2 * clamped))
}
