import Foundation

/// Shared rounding for percentage-based combat math on integer values.
public enum CombatRounding {
    /// Scales `value` by `multiplier` and rounds to the nearest integer (ties to even).
    public static func scaled(_ value: Int, multiplier: Double) -> Int {
        guard value > 0 else { return 0 }
        return rounded(Double(value) * multiplier)
    }

    /// Rounds a fractional combat result to the nearest non-negative integer.
    public static func rounded(_ value: Double) -> Int {
        max(0, Int(value.rounded()))
    }

    /// Applies an integer percent bonus to `value`, clamping at zero.
    public static func scaled(_ value: Int, byPercent percent: Int) -> Int {
        guard value > 0, percent != 0 else { return max(0, value) }
        return scaled(value, multiplier: 1.0 + Double(percent) / 100.0)
    }
}
