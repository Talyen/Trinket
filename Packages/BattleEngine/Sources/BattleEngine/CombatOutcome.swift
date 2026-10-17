public struct CombatOutcome: Equatable {
    public enum DamageImpact: Equatable, Sendable {
        case dodged
        case landed(blocked: Int, healthLost: Int)
    }

    public let healthDelta: Int
    public let damageImpact: DamageImpact?
    let flags: CombatFlags
    var elementalHit: ElementalReactionHit?

    init(
        healthDelta: Int = 0,
        flags: CombatFlags = [],
        damageImpact: DamageImpact? = nil,
    ) {
        self.healthDelta = healthDelta
        self.flags = flags
        self.damageImpact = damageImpact
    }

    public static var empty: Self {
        Self()
    }

    public var healthLost: Int {
        max(0, -healthDelta)
    }

    public var healthRestored: Int {
        max(0, healthDelta)
    }

    public var isCritical: Bool {
        flags.contains(.critical)
    }

    public var isDodged: Bool {
        flags.contains(.dodged)
    }
}

struct CombatFlags: OptionSet, Hashable, Sendable {
    let rawValue: UInt8

    static let critical = Self(rawValue: 1 << 0)
    static let dodged = Self(rawValue: 1 << 1)
    static let leeched = Self(rawValue: 1 << 2)
    static let controlTriggered = Self(rawValue: 1 << 3)
}

extension CombatOutcome {
    static func fromDamage(state: DamageResolutionState) -> CombatOutcome {
        var flags: CombatFlags = []
        if state.isCritical {
            flags.insert(.critical)
        }
        if state.isDodged {
            flags.insert(.dodged)
        }
        if state.didLeech {
            flags.insert(.leeched)
        }
        if state.didTriggerControl {
            flags.insert(.controlTriggered)
        }
        return CombatOutcome(
            healthDelta: -state.healthLost,
            flags: flags,
            damageImpact: state.options.isHealthCost ? nil
                : state.isDodged ? .dodged : .landed(blocked: state.blockedAmount, healthLost: state.healthLost),
        )
    }
}
