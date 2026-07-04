import Foundation
import TrinketCore
import TrinketContent

/// Step 6b: when a hero or pet would die for the first time, triggers Death's
/// Door (clamp to 1 HP and grant a short protection window). While active,
/// further lethal damage is clamped to 1 HP until the effect expires.
package struct DeathsDoorStep: DamageStep {
    public static let stepName = "DeathsDoor"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        state.damageEvents.append(contentsOf: DeathsDoorEngine.resolveAfterDamage(
            to: state.combatant,
            in: &context
        ))
    }
}
