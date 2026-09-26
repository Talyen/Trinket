/// Shared saturating integer arithmetic for domain curves and ledgers.
///
/// Centralizes the `*_reportingOverflow → Int.max` idiom previously hand-rolled
/// in `BattleGoldFlow`, `CombatantProgression`, `ExperienceScaling`, and
/// `CombatRounding` call sites. Saturation (never trapping) is the package
/// convention for unreachable-extreme inputs; normal values are unaffected.
public enum SaturatedArithmetic {
    /// Adds, saturating at `Int.max` on positive overflow.
    /// Negative overflow (below `Int.min`) clamps to `Int.min`.
    public static func saturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (result, overflow) = lhs.addingReportingOverflow(rhs)
        guard overflow else { return result }
        return lhs >= 0 ? Int.max : Int.min
    }

    /// Subtracts without trapping. Positive overflow saturates at `Int.max`;
    /// negative overflow saturates at `Int.min`.
    /// Handles `Int.min` operands that would trap with naive `-`.
    public static func saturatingSub(_ lhs: Int, _ rhs: Int) -> Int {
        let (result, overflow) = lhs.subtractingReportingOverflow(rhs)
        guard overflow else { return result }
        return lhs >= 0 ? Int.max : Int.min
    }

    /// Multiplies, saturating at `Int.max` on overflow.
    /// Used for XP ceilings; negative inputs are clamped to zero by callers.
    public static func saturatingMul(_ lhs: Int, _ rhs: Int) -> Int {
        let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        guard overflow else { return result }
        // Overflow sign follows operand signs; XP/ledger call sites only
        // saturate upward, so map positive overflow to Int.max.
        return (lhs > 0) == (rhs > 0) ? Int.max : Int.min
    }

    /// Scales a non-positive base to zero; saturates at `Int.max` instead of trapping.
    public static func scaled(_ value: Int, multiplier: Double) -> Int {
        guard value > 0 else { return 0 }
        return rounded(Double(value) * multiplier)
    }

    /// Scales a value by an integer percentage, clamping non-positive bases to zero.
    public static func scaled(_ value: Int, byPercent percent: Int) -> Int {
        guard value > 0, percent != 0 else { return max(0, value) }
        return scaled(value, multiplier: 1.0 + Double(percent) / 100.0)
    }

    /// Clamps negatives and non-finite inputs to zero; saturates at `Int.max`.
    /// Uses away-from-zero rounding (`Double.rounded()`), so exact .5 ties
    /// round away from zero (2.5 → 3). Non-finite multipliers therefore
    /// collapse through this path to zero rather than saturating.
    public static func rounded(_ value: Double) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        let rounded = value.rounded()
        guard rounded < Double(Int.max) else { return Int.max }
        return Int(rounded)
    }
}
