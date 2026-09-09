public struct BattleGoldFlow: Equatable, Hashable, Sendable {
    public private(set) var gained: Int
    public private(set) var spent: Int

    public init(gained: Int = 0, spent: Int = 0) {
        precondition(gained >= 0 && spent >= 0)
        self.gained = gained
        self.spent = spent
    }

    public var net: Int {
        gained - spent
    }

    public mutating func record(delta: Int) {
        if delta >= 0 {
            gained += delta
        } else {
            spent -= delta
        }
    }
}
