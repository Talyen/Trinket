import Foundation
import TrinketCore
import TrinketContent

/// Result of a combat mutation (damage, heal, leech, control meter).
public struct CombatOutcome: Equatable {
    /// Negative when the target lost health; positive when the target gained health.
    public var healthDelta: Int
    public var events: [ActionEvent]
    public var flags: Set<CombatFlag>

    public init(
        healthDelta: Int = 0,
        events: [ActionEvent] = [],
        flags: Set<CombatFlag> = []
    ) {
        self.healthDelta = healthDelta
        self.events = events
        self.flags = flags
    }

    public static var empty: CombatOutcome { CombatOutcome() }

    public var healthLost: Int {
        max(0, -healthDelta)
    }

    public var healthRestored: Int {
        max(0, healthDelta)
    }

    /// Alias retained while callers migrate from tuple returns.
    public var damageEvents: [ActionEvent] {
        events
    }
}

/// Semantic markers for combat mutations. Populated from pipeline state and events.
public enum CombatFlag: Hashable, Sendable {
    case dodged
    case shieldAbsorbed
    case leeched
    case controlTriggered
}

extension CombatOutcome {
    static func fromDamage(state: DamageResolutionState) -> CombatOutcome {
        var flags: Set<CombatFlag> = []
        if state.isDodged {
            flags.insert(.dodged)
        }
        if state.damageEvents.contains(where: { $0.effectKind == .shieldAbsorbed }) {
            flags.insert(.shieldAbsorbed)
        }
        if state.damageEvents.contains(where: { $0.effectKind == .leechHeal }) {
            flags.insert(.leeched)
        }
        if state.damageEvents.contains(where: { $0.effectKind == .controlTriggered }) {
            flags.insert(.controlTriggered)
        }
        return CombatOutcome(
            healthDelta: -state.healthLost,
            events: state.damageEvents,
            flags: flags
        )
    }
}
