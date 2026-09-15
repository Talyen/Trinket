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
        gained - spent
    }

    public mutating func record(delta: Int) {
        if delta >= 0 {
            let (next, overflow) = gained.addingReportingOverflow(delta)
            gained = overflow ? Int.max : next
        } else {
            let (next, overflow) = spent.subtractingReportingOverflow(delta)
            spent = overflow ? Int.max : next
        }
    }
}
