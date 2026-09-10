struct HealingResult {
    let directRestoration: Int
    let overflowTransferred: Int
    let isLeech: Bool
    let isCritical: Bool
    var events: [ActionEvent]

    static var empty: Self {
        Self(directRestoration: 0, overflowTransferred: 0, isLeech: false, isCritical: false, events: [])
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
        return CombatOutcome(healthDelta: directRestoration, events: events, flags: flags)
    }
}
