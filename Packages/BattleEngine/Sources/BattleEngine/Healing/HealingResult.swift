struct HealingAllocation {
    enum Destination {
        case transfer
        case maximumHealth
        case mana
        case block
    }

    let resolvedAmount: Int
    let directRestoration: Int
    private(set) var transferred = 0
    private(set) var maximumHealth = 0
    private(set) var block = 0
    private(set) var mana = 0

    var overflow: Int {
        max(0, resolvedAmount - directRestoration)
    }

    var remaining: Int {
        overflow - transferred - maximumHealth - block - mana
    }

    @discardableResult
    mutating func allocate(_ amount: Int, to destination: Destination) -> Int {
        let applied = CombatGain.amount(amount, current: 0, cap: remaining)
        switch destination {
        case .transfer: transferred += applied
        case .maximumHealth: maximumHealth += applied
        case .block: block += applied
        case .mana: mana += applied
        }
        return applied
    }
}

struct HealingResult {
    let allocation: HealingAllocation
    let isLeech: Bool
    let isCritical: Bool

    var directRestoration: Int {
        allocation.directRestoration
    }

    var overflowTransferred: Int {
        allocation.transferred
    }

    static var empty: Self {
        Self(allocation: HealingAllocation(resolvedAmount: 0, directRestoration: 0), isLeech: false, isCritical: false)
    }

    var didLeech: Bool {
        isLeech && (directRestoration > 0 || overflowTransferred > 0)
    }

    var combatOutcome: CombatOutcome {
        var flags: Set<CombatFlag> = []
        if isCritical {
            flags.insert(.critical)
        }
        if didLeech {
            flags.insert(.leeched)
        }
        return CombatOutcome(healthDelta: directRestoration, flags: flags)
    }
}
