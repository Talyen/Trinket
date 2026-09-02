import Foundation

public enum CombatRounding {
    public static func scaled(_ value: Int, multiplier: Double) -> Int {
        guard value > 0 else { return 0 }
        return rounded(Double(value) * multiplier)
    }

    public static func rounded(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        let rounded = value.rounded()
        guard rounded >= Double(Int.min), rounded <= Double(Int.max) else {
            return rounded > 0 ? Int.max : 0
        }
        return max(0, Int(rounded))
    }

    public static func scaled(_ value: Int, byPercent percent: Int) -> Int {
        guard value > 0, percent != 0 else { return max(0, value) }
        return scaled(value, multiplier: 1.0 + Double(percent) / 100.0)
    }
}
