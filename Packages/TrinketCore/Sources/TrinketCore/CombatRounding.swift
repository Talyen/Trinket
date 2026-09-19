import Foundation

public enum CombatRounding {
    /// Scales a non-positive base to zero; saturates at `Int.max` instead of trapping.
    /// Implementation lives in `SaturatedArithmetic`; kept here for call-site continuity.
    public static func scaled(_ value: Int, multiplier: Double) -> Int {
        SaturatedArithmetic.scaled(value, multiplier: multiplier)
    }

    /// Clamps negatives and non-finite inputs to zero; saturates at `Int.max`.
    /// Uses away-from-zero rounding (`Double.rounded()`), so exact .5 ties
    /// round away from zero (2.5 → 3). Non-finite multipliers therefore
    /// collapse through this path to zero rather than saturating.
    public static func rounded(_ value: Double) -> Int {
        SaturatedArithmetic.rounded(value)
    }

    public static func scaled(_ value: Int, byPercent percent: Int) -> Int {
        guard value > 0, percent != 0 else { return max(0, value) }
        return scaled(value, multiplier: 1.0 + Double(percent) / 100.0)
    }
}
