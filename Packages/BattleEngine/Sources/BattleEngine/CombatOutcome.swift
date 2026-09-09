import Foundation
import TrinketContent
import TrinketCore

public struct CombatOutcome: Equatable {
    public enum DamageImpact: Equatable {
        case dodged
        case landed(blocked: Int, healthLost: Int)
    }

    public var healthDelta: Int
    public var events: [ActionEvent]
    public var damageImpact: DamageImpact?
    var flags: Set<CombatFlag>

    public init(
        healthDelta: Int = 0,
        events: [ActionEvent] = [],
        flags: Set<CombatFlag> = [],
        damageImpact: DamageImpact? = nil,
    ) {
        self.healthDelta = healthDelta
        self.events = events
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

public enum CombatFlag: Hashable, Sendable {
    case critical
    case dodged
    case shieldAbsorbed
    case leeched
    case controlTriggered
}

extension CombatOutcome {
    static func fromDamage(state: DamageResolutionState) -> CombatOutcome {
        var flags: Set<CombatFlag> = []
        if state.isCritical {
            flags.insert(.critical)
        }
        if state.isDodged {
            flags.insert(.dodged)
        }
        if state.blockedAmount > 0 {
            flags.insert(.shieldAbsorbed)
        }
        if state.didLeech {
            flags.insert(.leeched)
        }
        if state.didTriggerControl {
            flags.insert(.controlTriggered)
        }
        return CombatOutcome(
            healthDelta: -state.healthLost,
            events: state.damageEvents,
            flags: flags,
            damageImpact: state.options.isHealthCost ? nil
                : state.isDodged ? .dodged : .landed(blocked: state.blockedAmount, healthLost: state.healthLost),
        )
    }
}
