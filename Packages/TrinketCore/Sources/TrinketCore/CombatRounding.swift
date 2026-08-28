import Foundation

public enum CombatRounding {
    public static func scaled(_ value: Int, multiplier: Double) -> Int {
        guard value > 0 else { return 0 }
        return rounded(Double(value) * multiplier)
    }

    public static func rounded(_ value: Double) -> Int {
        max(0, Int(value.rounded()))
    }

    public static func scaled(_ value: Int, byPercent percent: Int) -> Int {
        guard value > 0, percent != 0 else { return max(0, value) }
        return scaled(value, multiplier: 1.0 + Double(percent) / 100.0)
    }
}
