/// Battle gold ledger. Negative inputs clamp to zero; totals saturate at
/// `Int.max` instead of trapping on overflow.
public struct BattleGoldFlow: Equatable, Hashable, Sendable {
    public private(set) var gained: Int
    public private(set) var spent: Int

    public init(gained: Int = 0, spent: Int = 0) {
        self.gained = max(0, gained)
        self.spent = max(0, spent)
    }

    public var net: Int {
        SaturatedArithmetic.saturatingSub(gained, spent)
    }

    public mutating func record(delta: Int) {
        if delta >= 0 {
            gained = SaturatedArithmetic.saturatingAdd(gained, delta)
        } else {
            // Subtracting a negative delta adds its magnitude; the saturating
            // helper also covers Int.min without trapping on negation.
            spent = SaturatedArithmetic.saturatingSub(spent, delta)
        }
    }
}
