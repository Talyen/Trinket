import Foundation
import TrinketContent
import TrinketCore

public struct CombatOutcome: Equatable {
    public var healthDelta: Int
    public var events: [ActionEvent]
    var flags: Set<CombatFlag>

    public init(
        healthDelta: Int = 0,
        events: [ActionEvent] = [],
        flags: Set<CombatFlag> = [],
    ) {
        self.healthDelta = healthDelta
        self.events = events
        self.flags = flags
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
        for event in state.damageEvents {
            switch event.effectKind {
            case .shieldAbsorbed:
                flags.insert(.shieldAbsorbed)
            case .leechHeal:
                flags.insert(.leeched)
            case .controlTriggered:
                flags.insert(.controlTriggered)
            default:
                break
            }
        }
        return CombatOutcome(
            healthDelta: -state.healthLost,
            events: state.damageEvents,
            flags: flags,
        )
    }
}
